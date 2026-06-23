// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
Payable:
- a keyword that allows a function or address to receive Ether, WITHOUT it, any ETH sent with that call reverts
- payable functions cannot be view or pure : as view/pure never changes the state, while payable accepts the ETH which changes the state 
  That's permanently written on the blockchain.
 */

// ReentrancyGuard - mutex to block reentrant calls
// (simplified version of OpenZeppelin's)

abstract contract ReentrancyGuard {
    uint256 private _status;
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED; //lock
        _;
        _status = NOT_ENTERED; //unlock
    }
}

//main contract 
contract Payable is ReentrancyGuard{

    //state variables

    address public owner;

    //NOTE: Internal accounting - always check ETH yourself, never rely on address(this).balance for business logic
    uint public totalDeposited;

    //per-user balance tracker (pull pattern)
    mapping (address => uint) public balances;

    //claimable rewards (pull pattern for batch distribution)
    mapping (address => uint) public claimable;

    //events

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event FallbackTriggered(address sender, uint256 value, bytes data);
    event ReceiveTriggered(address sender, uint256 value);
    event RewardClaimed(address indexed user, uint256 amount);
    event ForcedETHDetected(uint256 contractBalance, uint256 trackedBalance);

    //payable constructor : contract can receive ETH at deploy time
    //without payable here, deploy reverts if ETH is sent

    constructor() payable{

        //msg.sender : the address that directly deployed the contract (when function: the address that directly called that function)
        //msg.value : the amount of ETH (expressed in wei) sent within the call
        owner = msg.sender;

        //if ETH was sent at deploy, account for it
        if (msg.value > 0){
            totalDeposited += msg.value;
            balances[msg.sender] += msg.value;
            emit Deposited(msg.sender, msg.value);
        }
    }

    // RECEIVING ETH
    // Core idea: 
    // - in a payable function the keyword `payable` enables the function to accept the ETH (without it, ETH sent reverts)
    // - msg.value: it can only be non-zero if the call carries ETH
    // - (IN REAL PRACTICE) - msg.value requires a receiving function or constructor to be payable, otherwise the transaction reverts

    function deposit() external payable{
        // Security concern: always validate the msg.value as zero deposits wastes gas and can pollute the accounting
        require(msg.value > 0, "Must send ETH");

        //NOTE: update the internal accounting before any external interaction
        balances[msg.sender] += msg.value;
        totalDeposited += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    /**
    RECEIVE():
    
    Triggered when:
    - ETH is sent to this contract
    - msg.data is empty (no function selector)
    e.g. user sends ETH via MetaMask without calling any function

    Rules:
    - must be external 
    - must be payable
    - no arguments, no return value
    - ONLY ONE PER CONTRACT

    Security concern:

    - if receive() is missing and no payable fallback exists, plain ETH transfers revert silently from the sender's perspective
    - A protocol expecting to receive ETH without function calls will break
     */

    receive() external payable{
        emit ReceiveTriggered(msg.sender, msg.value);

        //route to deposit logic so accounting stays correct
        if (msg.value > 0){
            balances[msg.sender] += msg.value;
            totalDeposited += msg.value;
        }
    }

    /**
    FALLBACK()

    Triggered when : 
    - no function signature matched msg.data
    - OR: ETH sent + no receive() exists

    Rules:
    - must be external
    - can be payable or not
    - access msg.data to inspect what was called

    Decision tree:

        ETH arrives
            |
        msg.data empty?
             |
           /   \
        yes     no
         |       |
    receive()    fallback()
    (if exists)  (if payable or not)
        |
    NO receive?
        |
    fallback()

    Security concern:

    - A non payable fallback with no receive() means the contract cannot accept plain ETH transfers at all

     */

    fallback() external payable{
        emit FallbackTriggered(msg.sender, msg.value, msg.data);

        //Security concern: Do not silently accept ETH in fallback without accounting
        //If msg.value > 0 and you don't track it, those funds are trapped.

        if (msg.value > 0){
            balances[msg.sender] += msg.value;
            totalDeposited += msg.value;
        }
    }

    /**
    SENDING ETH OUT

    ADDRESS PAYABLE + TRANSFER METHODS

    To send ETH out of a contract you need:
    1. Contract has enough ETH balance
    2. Recipient cast to address payable
    3. One of the three sending methods

    Three ETH sending methods :

    .transfer(amount):

    - sends ETH using an internal EVM CALL opcode
    - forwards a fixed 2300 gas to the receiver
    - executes the receiver's receive() or fallback() function
    - if the receiver:
        - reverts
        - runs out of gas
        - or needs more than 2300 gas,
        - then the call fails
    - transfer() automatically propagates that failure by reverting the entire transaction 
    - returns no value
    - NOT RECOMMENDED: because 2300 gas is often insufficient for modern smart contract wallets and receiver contracts

    .send()

    - sends ETH using an internal EVM CALL opcode
    - forwards a fixed 2300 gas to the receiver
    - executes the receiver's receive() or fallback() function
    - if the receiver:
        - reverts
        - runs out of gas
        - or needs more than 2300 gas,
        - then the call fails
    - unlike transfer(), it does not revert automatically
    - returns: bool success
    - caller must manually check the return value: require(success);
    - NOT RECOMMENDED: because same 2300-gas limitation as transfer()
    - easy to forget checking the return value

    .call{value: amount}("")

    - sends ETH using a low-level EVM CALL opcode
    - forward all remaining gas by default (unless specified otherwise)
    - executes the receiver's receive() or fallback() function
    - receiver can perform complex logic because it has sufficient gas
    - if the receiver fails, call() does not automatically revert
    - returns: (bool success, bytes memory data)
    - caller must manually check: require(success)
    - RECOMMENDED because:
        - works with smart contract wallets
        - works with ERC-4337/account abstraction wallets
        - not dependent on the fragile 2300-gas stipend
        - provides access to returned data

    Why 2300 gas breaks the smart contract wallet?
    - Gnosis safe, ERC-4337 AA wallets need > 2300 gas in their receive() to execute their internal logic.
      .transfer() / .send() silently breaks these.
    */

    //using .transfer() just for this documentation
    function badWithdrawTransfer() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "Nothing to withdraw");
        balances[msg.sender] = 0;
        totalDeposited -= amount;
        //breaks for smart contract wallet users
        payable(msg.sender).transfer(amount);
    }

    //using .send() with unchecked return value (not recommended) 
    function badWithdrawSend() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "Nothing to withdraw");
        balances[msg.sender] = 0;
        totalDeposited -= amount;
        //return value ignored - silent failure
        payable(msg.sender).send(amount);
    }

    /**
    SAFE WITHDRAWAL (all patterns combined)

    PULL-OVER-PUSH PATTERN
    CHECKS-EFFECTS-INTERACTIONS (CEI)
    REENTRANCY GUARD

    CEI order:
        - Checks : require statements
        - Effects : state changes(balances zeroed before call)
        - Interactions : external call (ETH sent Last)

    Why the order matters?
    - if you sent ETH first, the recipient's receive() runs before your state update.
      They can call withdraw() again inside receive() and your balance still shows the old value.
      (commonly known as reentrancy)

    nonReentrant adds a primary mutex as a second line of defense.
    CEI is the primary defense. 
    nonReentrant is a backup.
     */

    function withdraw() external nonReentrant {

        //checks
        uint256 amount = balances[msg.sender];
        require(amount > 0, "Nothing to withdraw");
        require(address(this).balance >= amount, "Contract underfunded");
    
        //effects - zero state before external call
        balances[msg.sender] = 0;
        totalDeposited -= amount;

        //interactions - external call goes last
        (bool ok, bytes memory err) = payable(msg.sender).call{value : amount}("");
        //Security concern: always check the bool from .call(), if not checked - ETH is lost silently, no revert
        require(ok, string(err));

        emit Withdrawn(msg.sender, amount);

    }

    // BUGS TO STUDY (SECURITY CONCERN)

    /**
    msg.value in a loop - critical bug

    msg.value is GLOBAL for the entire transaction
    it does not decrease as you use it inside a loop

    Attack scenario:
        user = [A, B, C, D]
        attacker sends 1 ETH
        each user gets credited 1 ETH: protocol owes 5 ETH
        but only 1 ETH was deposited: protocol is drained
     */

    //vulnerable - DO NOT USE
    function batchDepositedBad (address[] calldata users) external payable {
        for (uint256 i = 0; i < users.length ; i++){
            //msg.value is 1 ETH every single iteration
            balances[users[i]] += msg.value;
            totalDeposited += msg.value;
        }
    }

    //correct - divide msg.value across recipients
    function batchDepositedGood(address[] calldata users) external payable {
        require(users.length > 0, "Empty array");
        require(msg.value > 0, "No ETH sent");

        uint256 share = msg.value /users.length;
        uint256 distributed = 0; 
        for (uint256 i = 0; i < users.length; i++){
            balances[users[i]] += share;
            distributed += share;
        }
        totalDeposited += distributed;

        //return dust from integer division to sender
        uint256 dust = msg.value - distributed;
        if (dust > 0){
            (bool ok,) = payable(msg.sender).call{value: dust}("");
            require(ok, "Dust refund failed");
        }
    }

    /**
    BATCH PAYMENT GRIEFING - push pattern vulnerability

    if even one recipient reverts in receive(), the entire batch fails. A malicious user can block everyone else's payment forever
    fix: pull pattern - let users claim individually
     */

    //vulnerable
    function pushRewardsBad(address[] calldata users, uint256 amount) external{
        require(msg.sender == owner, "Only owner");
        for (uint256 i = 0; i < users.length; i++){
            //if users[i] is a contract with reverting receive()
            //this entire transaction reverts
            (bool ok,) = payable(users[i]).call{value: amount}("");
            require(ok, "Transfer failed"); // one failure kills all
        }
    }

    //correct - pull pattern 
    //owner sets claimable balances, users pull their own ETH
    function setClaimable(address[] calldata users, uint256 amount) external {
        require(msg.sender == owner, "Only owner");
        for (uint i = 0; i < users.length; i++){
            claimable[users[i]] += amount;
        }
    }

    function claimReward() external nonReentrant {
        uint256 amount = claimable[msg.sender];
        require(amount > 0, "Nothing to claim");

        //CEI: effect first
        claimable[msg.sender] = 0;
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "Claim failed");

        emit RewardClaimed(msg.sender, amount);
    }

    /**
    Force ETH via selfdestruct
    
    A contract can receive ETH even without receive() or fallback()
    if another contract selfdestructs and sends ETH to it
    This bypasses all checks - receive() is never called.

    as of EIP-6780 (Dencun upgrade, March 2024), selfdestruct only sends ETH 
    if the contract is created and destroyed in the same transaction.
    The general selfdestruct behaviour is now limited!

    result: address(this).balance > totalDeposited

    ADDRESS(THIS).BALANCE AS INVARIANT - BUG

    Any logic that assumes:
    address(this).balance == totalDeposited
    can be broken by force-sending ETH via selfdestruct.
     */

    //vulnerable - balance can be externally manipulated
    function isBalanceIntactBad() external view returns (bool){
        //selfdestruct from another contract breaks this forever
        return address(this).balance == totalDeposited;
    }

    //correct - use internal accounting, not raw balance
    function isBalanceIntactGood() external view returns (bool){
        //totalDeposited is only changed by our own logic
        //address(this).balance might be higher due to force-ETH
        //that's okay - we only care about we're tracking
        return address(this).balance >= totalDeposited;
    }

    //helper to detect forced ETH (for monitoring/alerting)
    function detectForcedETH() external{
        if (address(this).balance > totalDeposited){
            emit ForcedETHDetected(address(this).balance, totalDeposited);
        }
    }

    //VIEW HELPERS

    function getContractBalance() external view returns(uint256){
        return address(this).balance;
    }

    function getUserBalance(address user) external view returns (uint256){
        return balances[user];
    }

    function getTrackedTotal() external view returns (uint256){
        return totalDeposited; 
    }

    function getUnaccountedETH() external view returns (uint256){
        uint bal = address(this).balance;
        if (bal > totalDeposited) {
            return bal - totalDeposited;
        }
        return 0;
    }

}

//FORCE ETH CONTRACT - demonstrates selfdestruct ETH injection
//(shows why address(this).balance is unreliable as invariant)

contract ForceETHSender {
    constructor(address target) payable {
        //selfdestruct sends all ETH to target
        //bypasses receive() and fallback() completely
        selfdestruct(payable(target));
    }
}