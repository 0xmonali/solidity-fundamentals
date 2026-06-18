// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35; 

/**
CALL AND DELEGATECALL 

Two low-level EVM opcodes for inter-contract interaction
Both bypasses Solidity's type system - that's power and  danger combined

CALL - executes code in the TARGET's context (target's storage, target's identity)
DELEGATECALL - executes code in the CALLER's context (caller's storage, caller's identity)
*/

/**
.CALL()

.call() is a low-level EVM message-call primitive exposed by Solidity that allows a contract to invoke 
code at another address by supplying arbitrary calldata and optional ETH, returning(bool success, bytes memory returndata) 
instead of automatically decoding the result

syntax: (bool success, bytes memory returndata) = target.call{value: amount}(calldata);

Breaking it down:
- target: address being called
- calldata: ABI-encoded function selector + arguments
- value: optional ETH sent with the call
- success: whether the EVM call completed without reverting
- returndata : raw bytes returned by the callee

.call() is Solidity's wrapper around the EVM CALL OPCODE for performing 
arbitrary external message calls using raw calldata and optional ETH transfer

.call():
- does not perform compile-time type checking
- does not automatically decode return values
- operates directly on raw bytes

At EVM level, Solidity's target.call(...) ultimately compiles to the EVM CALL opcode

The CALL opcode:
1. creates a new execution context
2. transfer control to the target address
3. optionally transfers ETH
4. Executes the target's code
5. Return a success flag and return data

When to use .call():
- sending ETH to an address (recommended method - covered in Payable.sol)
- calling a contract when you don't have its interface/ABI at the compile time
- calling a contract when you need custom gas control

When not to use .call() for existing functions:
- reverts from the target are not bubbled up automatically (success == true is returned, but no revert reason unless return data is decoded manually)
- type checks are bypassed - wrong argument types won't be caught at compile time
- function existence is not checked - calling a non-existent function triggers fallback() silently instead of reverting

PREFERRED for known contracts: use interfaces
interface IReceiver {
    function foo(string memory _message, uint256 _x) external payable returns (uint256);
    }
IReceiver(addr).foo("hello",123); //type-safe, reverts bubble up, existence checked

*/

contract Receiver {
    event Received(address caller, uint256 amount, string message);

    receive() external payable {
        emit Received(msg.sender, msg.value, "receive triggered - plain ETH transfer");
    }

    fallback() external payable {
        emit Received(msg.sender, msg.value, "fallback triggered - no matching selector");
    }

    function foo(string memory _message, uint256 _x) public payable returns (uint256) {
        emit Received(msg.sender, msg.value, _message);
        return _x + 1;
    }
}

contract Caller {
    
    event Response(bool success, bytes data);

    /**
    Three ways to encode calldata for .call()

    1. abi.encodeWithSignature("foo(string, uint256)", arg1, arg2)
        - takes the function signature as a string
        - computes selector internally via keccak256
        - Security concern: typo in string  = wrong selector + fallback() triggered silently
          e.g. "foo(string, uint256)" with a space -> wrong selector, no compile error
    
    2. abi.encodeWithSelector(bytes4 selector, arg1, arg2)
        - takes a precomputed selector
        - slightly more gas efficient (selector computed at compile time)
        - e.g. abi.encodeWithSelector(Receiver.foo.selector, "hello", 123)

    3. abi.encodeCall(function, (args))
        - TYPE SAFE version - compiler checks argument types
        - recommended over encodeWithSignature for known interfaces
        - e.g. abi.encodeCall(Receiver.foo, ("hello", 123))
        
    */

    function testCallFoo(address payable _addr) external payable {
        //type-safe encoding - compiler catches wrong arg types
        (bool success, bytes memory data) = _addr.call{value: msg.value}(abi.encodeCall(Receiver.foo, ("call foo", 123)));

        //Security concern: success == true does not mean the return value is what you expect
        //it means the call did not revert - always decode and validate return data
        require(success, "call failed");

        //decoding return data: abi.decode(data, (types))
        uint256 result = abi.decode(data, (uint256));
        emit Response(success, abi.encode(result));
    }

    /**
    CALLING A NON-EXISTENT FUNCTION

    If the selector doesn't match any function on the target:
    - target's fallback() is triggered (if it exists and is payable if ETH is sent)
    - success = true if fallback() runs without reverting
    - success = false if fallback() reverts or doesn't exist

    Security concern: this was a silent misdirect
    - I was thinking that i was calling "doesNotExist()" but I was actually hitting the fallback()
    - if fallback() has side effects, those run instead
    - no compile time or runtime error to warn you
    */
    function testCallDoesNotExist(address payable _addr) external payable {
        (bool success, bytes memory data) = _addr.call{value:msg.value}(abi.encodeWithSignature("doesNotExist()"));
        emit Response(success, data);
    }
}


/**
DELEGATECALL

when contract A does delegatecall to contract B:
- B's CODE runs
- but inside A's STORAGE, A's msg.sender, A's msg.value

Think of it as: "borrow B's logic, run it on my own data"

Real - world use: PROXY PATTERN
- proxy contract holds storage + ETH
- logic/implementation contract holds code
- proxy delegate all calls to logic via delegatecall
- to upgrade: point proxy to a new logic contract
- storage stays intact, only the code changes

STORAGE LAYOUT - THE MOST CRITICAL CONCEPT

delegatecall operates on SLOT POSITION, not variable names.
If A and B have different variable order, B's code writes to wrong slots in A.

    contract B {uint256 public num; address public sender;}
    contract A {address public owner; uint256 public count;}

    A does delegatecall to B's setVars():
    - B writes num -> slot 0 -> overwrites A's owner <- CRITICAL BUG
    - B writes sender -> slot 1 -> overwrites A's count

Security concern (storage collision) : 
This is one of the most dangerous bugs in proxy systems.
Always verify that proxy and implementation share identical storage layout.
OpenZeppelin solves this with EIP-1967: stores implementation address at a specific pseudo-random
slot (keccak256 hash) to avoid collision with normal variables.

(msg.sender preservation):
In delegatecall, msg.sender is the ORIGINAL caller, not the proxy.
This matters for access control: if implementation checks msg.sender == owner,
it's checking against the original EOA, not the proxy address.
Can be exploited if the implementation has functions that assume msg.sender is a trusted contract.

 */

//Deploy B first
contract B{
    //storage layout must match A exactly - slot 0, slot 1, slot 2
    uint256 public num; //slot 0
    address public sender; //slot 1
    uint256 public value; //slot 2

    function setVars(uint256 _num) public payable {
        //this code runs in whoever delegatecalls this
        // num/sender/value here refer to slot 0/1/2 of the CALLER's storage
        num = _num;
        sender = msg.sender;
        value = msg.value;
    }
}

contract A {
    // must match B's layout exactly
    uint256 public num; //slot 0
    address public sender; //slot 1
    uint256 public value; //slot 2
    
    event DelegateResponse(bool success, bytes data);
    event CallResponse(bool success, bytes data);

    /**
    DELEGATECALL: B's code runs, A's storage is modified
    - A.num, A.sender, A.value get updated
    - B's storage untouched
    - msg.sender inside B = whoever called A(original EOA)
     */
    function setVarsDelegateCall(address _contract, uint256 _num) public payable{
        (bool success, bytes memory data) = _contract.delegatecall(abi.encodeWithSignature("setVars(uint256)", _num));

        //Security concern: delegatecall success = false is silent
        //no revert reason bubbled up by default - always require(success)
        require(success, "delegatecall failed");
        emit DelegateResponse(success, data);
    }

    /** 
    CALL: B's code runs, B's storage is modified
    - B.num, B.sender, B.value get updated
    - A's storage untouched
    - msg.sender inside B = address(A) (the intermediary)
     */

    function setVarsCall(address _contract, uint256 _num) public payable{
        (bool success, bytes memory data) = _contract.call{value: msg.value}(abi.encodeWithSignature("setVars(uint256)", _num));
        require(success, "call failed");
        emit CallResponse(success, data);
    }
}

/**
CALL VS DELEGATECALL - quick reference

                        .call()                 .delegatecall()
code executed           target's                target's 
storage modified        target's                caller's
msg.sender              caller                  original caller (EOA)
msg.value               new value               original value
ETH transferred         yes(if payable)         no (ETH stays in caller)
use case                general interaction     proxy pattern / upgrades
main risk               unchecked return        storage layout mismatch

Security concern (delegatecall to untrusted contract):
if A does delegatecall to a contract it doesn't control, that contract can execute ANYTHING in A's
storage context.
It can wipe A's storage, drain A's ETH, change A's owner.
Never delegatecall to any address that isn't a trusted, audited contract.
 */