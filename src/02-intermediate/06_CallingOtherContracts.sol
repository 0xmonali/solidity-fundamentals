// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26; 

/**
CALLING OTHER CONTRACTS

Basics (what and why):

- A "contract call"is how one deployed contract invokes a function on another 
  deployed contract. Under the hood this is the EVM's CALL family of opcodes 
  (CALL, STATICCALL, DELEGATECALL). Conceptually it's similar to calling a function 
  on an object in normal programming, EXCEPT:
  
    - the "object" (target contract) may be mailcious or buggy
    - the call can fail partway and you must explicitly handle that
    - the callee can execute arbitrary code, including calling back into you

- This file demonstrates the three main call styles
    - interface calls
    - low-level calls
    - staticcall
*/

//MINIMAL TARGET CONTRACT USED BY THE EXAMPLES BELOW

contract Callee {
    uint256 public x;

    function setX(uint256 _x) external returns (uint256){
        x = _x;
        return x;
    }

    function setXandSendEther(uint256 _x) external payable returns (uint256, uint256) {
        x = _x;
        return (x, msg.value);
    }

    function getX() external view returns(uint256) {
        return x;
    }
}

contract Caller {
    /**
    1. Interface calls (the "normal" way)

    WHAT THIS IS: writing `_callee.setX(_x)` like a normal function call.
    The compiler knows Callee's ABI (from the type), so it encodes the 
    function selector + arguments for you and emits a CALL opcode.
    This is the style mostly used by the developers.

    Compiles down to a CALL opcode under the hood. By default ALL
    remaining gas is forwarded unless you specify {gas: ...}.
    If the callee reverts, this call reverts automatically - 
    NO need to manually check a return bool here.

    */
    function callSetX(Callee _callee, uint256 _x) external {
    /**
    (unused return is intentional here - same setX call as above, just demonstrating the 
    interface-call style itself)
     */
        _callee.setX(_x);
    /**
    Security concern: 
    _callee is a parameter, fully attacker-controlled
    if this function is public/external without an allowist check.
    Calling an arbitrary user-supplied address means that address's 
    code runs with whatever logic the attacker wrote - including 
    reentering this contract. Always ask: "can the caller choose an arbitrary target here, 
    and if so, is that intended?" 
     */
   }

    function callSetXandSendEther(Callee _callee, uint256 _x) external payable {
        _callee.setXandSendEther{value: msg.value}(_x);

        /**
        Security concern:
        forwarding msg.value to an arbitrary target is a classic vector for fund-draining 
        if _callee is not validated.
        Also note: this function inherits the CEI ordering of whatever function calls it -
        if this is called mid-way through a larger flow, the external call above can re-enter 
        before later state updates in the *caller's* caller execute.
        */
    }

    /**
    2. Low-level call() - the most audit-relevant pattern

    WHAT THIS IS: every address is Solidity has a built-in `.call()`
    method. Unlike the interface call above, here build the function call
    manually with abi.encodeWithSignature(...), and Solidity has NO knowledge 
    of what's on the other end - it could be a contract, an EOA, or nothing at 
    all. Used when the target type/ABI isn't known at compile time, or when you 
    need fine control over gas.

     */
    function lowLevelCall(address _addr, uint256 _x) external payable {
        // call() returns (bool success, bytes memory data) and does NOT automatically revert on failure
        (bool success, bytes memory data) = _addr.call{value: msg.value, gas: 5000}(
            abi.encodeWithSignature("setX(uint256)", _x)
        );
        data; //silence unused-var warning - `data` is discussed below

        /**
        Security concern (CRITICAL, most common audit finding):

        If you forget the require/if-check below, the call can silently 
        fail - msg.value may be lost or state assumptions broken - while 
        execution continues as if it succeeded. ALWAYS CHECK success.
        */
        require(success, "low-level call failed");

        /**
        Security concern:
        `data` here is the raw ABI-encoded return value.
        If you abi.decode() it without validating length first, a 
        malicious callee can return a huge "return bomb" payload to 
        burn the caller's gas during decoding, or return malformed
        data that causes the decode to revert unexpectedly.
         */
    }

    //Calling a function that does not exist - lands in receive/fallback
    function callDoesNotExist(address _addr) external {
        (bool success, ) = _addr.call(
            abi.encodeWithSignature("doesNotExist()")
        );
        require(success, "call failed");
        /**
        Security concern:

        gas forwarded by default here is "all remaining gas" since no {gas: ...}
        was specified. If _addr is untrusted, its fallback can perform arbitrary work,
        including reentrancy and gas-griefing of the rest of this transaction.
        */
    }

    /**
    3. staticcall() - read-only external calls

    WHAT THIS IS: identical to call() mechanically, except the EVM enforces that the callee
    CANNOT modify any state. Use this when you need to read data from another contract and 
    want a guarantee (enforced by the EVM itself, not just convention) that nothing changes 
    as a side effect.  
     */

    function readOnlyCall(Callee _callee) external view returns(uint256) {
        (bool success, bytes memory data) = address(_callee).staticcall(
            abi.encodeWithSignature("getX()")
        );
        require(success, "staticcall failed");
        return abi.decode(data,(uint256));

        /**
        Security note:
        
        staticcall reverts automatically if the callee attempts ANY state-changing opcode
        (SSTORE, CREATE, SELFDESTRUCT, LOG, or a nested CALL that sends value). This makes 
        it safe for "trust but verify the target can't mutate state" reads, but it does NOT 
        protect against the callee returning manipulated data (e.g., a price oracle staticcall
        can still return a stale or manipulated value - staticcall only guarantees no state mutation,
        not data correctness).
        */
    }

    //4. Reentrancy-safe pattern refernce (checks-effects-interactions)

    mapping(address => uint256) public balances;

    //VUNERABLE version - interaction before effect.
    function withdrawVulnerable() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "nothing to withdraw");

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "send failed");

        balances[msg.sender] = 0;
        /**
        Security concern (classic reentrancy) :
        The external call happens BEFORE balances[msg.sender] is zeroed. A malicious msg.sender
        contract's receive() can call withdrawVulnerable() again before the first call frame finishes, 
        draining the contract by repeatedly passing the `amount > 0` check with stale state.
        */
    }

    //SAFE version - effect before interaction (CEI pattern).
    function withdrawSafe() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "nothing to withdraw");

        balances[msg.sender] = 0; // effect first

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "send failed");

        /**
        Even though this is still a raw call() with full gas forwarding,
        reentering here just sees balances[msg.sender] == 0, so the require
        at the top of a re-entrant call fails harmlessly.
         */
    }
}