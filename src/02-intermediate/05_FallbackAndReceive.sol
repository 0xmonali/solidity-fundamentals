// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26; 

/**
FALLBACK AND RECEIVE:

receive():

- It is a special external payable function that is automatically
  executed when a contract receives Ether with empty calldata (msg.data.length == 0) 

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

fallback():

- It is a special external function that is automatically executed when a call's function 
  selector does not match any function in the contract, or when calldata is non-empty and 
  no matching function exists. If marked payable, it can also receive Ether.

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

contract Fallback{
    
    event Log (string func, uint256 gasleft, address sender, uint256 value);

    receive() external payable {

        //gasleft() here shows how much gas was forwarded to this call
        //called via .transfer()/.send() -> 2300 gas remaining
        //called via .call() -> most of the transaction gas remaining
        emit Log("receive", gasleft(), msg.sender, msg.value);
    }

    fallback() external payable {

        //same gas observation applies here
        //if msg.data was non-empty, this fired instead of receive()
        emit Log("fallback", gasleft(), msg.sender, msg.value);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

/**
SENDER CONTRACT 

Demonstrate which special function gets triggered and why?

    transferToFallback():
        - uses .transfer()
        - msg.data is empty -> receive() fires
        - only 2300 gas forwarded -> check gasleft() in the log

    callFallback():
        - uses .call() with empty data ""
        - msg.data is empty -> receive() fires
        - all remaining gas forwarded -> gasleft() will be much higher

NOTE: to trigger fallback() instead of receive(),
Need to send with non-empty msg.data (wrong function selector etc.)
Both functions here send empty data so receive() always fires on Fallback contract.

*/

contract SendToFallback {

    //triggers receive() on target - 2300 gas only
    function transferToFallback(address payable _to) external payable {
        _to.transfer(msg.value);
    }

    //triggers receive() on target - full gas forwarded
    function callFallback(address payable _to) external payable{
        (bool sent,) = _to.call{value: msg.value}("");
        require(sent, "Failed to send Ether");
    }
}

/**
FALLBACK WITH BYTES INPUT/OUTPUT

fallback can optionally take bytes calldata and return bytes memory.
This is the foundation of the PROXY PATTERN.

The proxy has no real logic of its own.
Every call hits its fallback, which forwards the new calldata to the implementation contract
The caller thinks they're talking to the proxy but the logic runs elsewhere.

Security concern (proxy risks):
- uninitialised implementation slot = critical bug
  anyone can call initialize() and take ownership before the real owner does
- mutable implementation address needs strict access control on upgrades
- fallback blindly forwards ALL calls - no function is blocked by default
- always audit: WHAT can be called on the implementation through this proxy?

*/

contract FallbackInputOutput {

    //immutable = set once at deploy, cannot be changed
    // safe here but real proxies use a storage slot for upgradability (EIP-1967)

    address immutable target;

    constructor(address _target) {
        target = _target;
    }

    /**
    This fallback is the proxy:
    - intercepts every call (since no other functions exists)
    - receives raw calldata (function selector + encoded args)
    - forwards it to target with .call()
    - return whatever target returns

    Security concern:
    - msg.value is forwarded blindly - ensure target handles ETH correctly
    - ignoring require(ok) here = silent failure, funds or state changes lost 

    */

    fallback(bytes calldata data) external payable returns (bytes memory) {
        (bool ok, bytes memory res) = target.call{value: msg.value}(data);
        require(ok, "call failed");
        return res;
    }
}

/** 
Counter contract

Minimal target for the proxy demo above.
get() and inc() are the two functions TestFallbackInputOutput builds calldata 
for and routes through FallbackInputOutput.

 */

contract Counter{

    uint256 public count;

    function get() external view returns (uint256) {
        return count;
    }

    function inc() external{
        count += 1;
    }
    
}

/**
TEST CONTRACT 

builds the calldata for Counter functions and sends it through the proxy

abi.encodeCall(Counter.get, ())
- encodes the function selector for get() into bytes
- this is the msg.data  looks like when someone calls get()

test() sends that bytes calldata to FallbackInputOutput,
FallbackInputOutput's fallback forwards it to Counter,
Counter executes the function and returns the result.
*/

contract TestFallbackInputOutput {

    event Log(bytes res);

    function test(address _fallback, bytes calldata data) external {
        (bool ok, bytes memory res) = _fallback.call(data);
        require(ok, "call failed");
        emit Log(res);
    }

    //pure: no state read or write, just ABI encoding math
    function getTestData() external pure returns (bytes memory, bytes memory) {
        return (
            abi.encodeCall(Counter.get, ()),
            abi.encodeCall(Counter.inc, ())
        );
    }
}

/**
Security concerns:

1.Gas stipend trap:

    .transfer()/.send() forward a fixed 2300 gas to receive()/fallback().
    That's not enough for any SSTORE - a cold slot first write costs 22,100 gas 
    (2,100 cold access + 20,000 set), a cold slot modifying an existing value costs 
    5,000 gas (2,100 cold access + 2,900 reset), and even a warm slot modify still 
    costs 2,900 gas. Any of these, or any external call, will revert under the stipend. 
    .call{value: x}("") forwards all available gas and is the modern standard, but it 
    means receive()/fallback() must defend against reentrancy themselves since there's no 
    longer a gas-based safety net.

2. Fallback as silent catch all

    Any payable fallback with real logic means a mistyped or wrong-ABI call 
    doesn't revert, it executes fallback code instead. 
    ALWAYS ASK: What's the blast radius if fallback fires unintentionally?

3. Forced ether/balance invariants 

    selfdestruct targeting a contract, or pre-funding a CREATE2 address 
    before deployment, lands ETH in address(this).balance with zero calls 
    to receive() or fallback(). Any == check against the contract's balance
    is a finding. This single bug class shows up constantly in Code4rena/CodeHawks
    reports.

4. CEI
    
    states changes before external calls. This is the DAO hack fix, baseline hygiene,
    but worth annotating every time so the absence of it jumps out elsewhere in a codebase

5. Privilege logic hidden in fallback

    This fallback silently reassigns `owner` on a tiny, condition-gated ETH transfer,
    with no access control and no relation to its name. Attack path: call contribute() 
    with <0.001 ether (any nonzero amount satisfies contributions[msg.sender] > 0), then 
    send plain ETH via receive-style call - fallback fires, msg.value > 0 passes, 
    ownership flips to attacker. Root cause: payable fallback performing a privileged state 
    change with only a `msg.value > 0` gate.

 */