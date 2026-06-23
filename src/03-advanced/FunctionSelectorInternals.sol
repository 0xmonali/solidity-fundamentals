// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26; 

/**
Function selector

Every external function call on Ethereum starts with 4 bytes in msg.data.
These 4 bytes are the function selector - the EVM's way of knowing which function to run.
*/

/**
HOW A SELECTOR IS COMPUTED

selector = bytes4(keccak256(bytes("functionName(type1,type2,...)")))

Rules for the signature string:
- function name + parameter types in parentheses
- NO spaces anywhere (spaces = differnet hash = wrong selector)
- NO parameter names, only types
- use CANONICAL types: uint -> wrong, must be uint256
                        int -> wrong, must be int256
- tuple types use syntax: (type1,type2)
- arrays: uint256[] or uint256[3]

common mistakes:
"transfer(address, uint256)" <- space after comma -> wrong selector  
"transfer(address,uint)" <- uint not uint256 -> wrong selector
"transfer(address,uint256)" <- correct

Security concern:
abi.encodeWithSignature takes a raw string - typos compile fine but produce wrong selectors 
which silently hit fallback() instead of the target function. abi.encodeCall avoids this entirely
because it's type-checked at compile time.

*/

contract FunctionSelector{

    /**
    getSelector() - compute any function's selector at runtime
    input: "transfer(address,uint256)"
    output: 0xa9059cbb (first 4 bytes of keccak256 hash)

    known selectors worth memorizing:
    transfer(address,uint256) -> 0xa9059cbb (ERC20 transfer)
    transferFrom(address,address,uint256) -> 0x23b872dd (ERC20 transferFrom)
    approve(address,uint256) -> 0x095ea7b3 (ERC20 approve)
    balanceOf(address) -> 0x70a08231 (ERC20 balanceOf)

    */

    function getSelector(string calldata _func) external pure returns (bytes4) {
        return bytes4(keccak256(bytes(_func)));
    }

    // get selector directly from a known function reference (safer) 
    // safer : because the compiler verifies the function exists and the types match- no string, no typo risk
    function getFooSelector() external pure returns(bytes4) {
        // Solidity built-in: ContractName.functionName.FunctionSelector
        // computed at compile time, type-safe, no string typo risk
        return FunctionSelector.getSelector.selector;
    }
}

/**
ABI ENCODING METHODS COMPARED

Three ways to build calldata for .call():

1. abi.encodeWithSignature(string, args...)
    - computes selector from string at runtime
    - no type checking on args
    - typo in string = wrong selector, no error
    - least safe

2. abi.encodeWithSelector(bytes4, args...)
    - takes precomputed selector
    - no type checking on args
    - selector computed at compile time if you use .selector
    - more gas efficient than encodeWithSignature

3. abi.encodeCall(function reference, (args))
    - TYPE SAFE: compile checks arg types against function signature
    - selector computed at compile time
    - recommended for known interfaces
    - most safe

Security concern:
When reviewing code that uses .call(), check which encoding method is used.
encodeWithSignature with a string is a red flag for potential typos.

*/

interface ITarget {
    function setVars(uint256 _num) external;
}

contract EncodingComparison {

    address immutable target;

    constructor(address _target) {
        target = _target;
    }

    //least safe - string typo risk
    function callWithSignature(uint256 _num) external {
        (bool ok,) = target.call(abi.encodeWithSignature("setVars(uint256)", _num));
        require(ok, "failed");
    }

    //better - selector precomputed, but args still unchecked
    function callWithSelector(uint256 _num) external {
        bytes4 selector = bytes4(keccak256("setVars(uint256)"));
        (bool ok,) = target.call(abi.encodeWithSelector(selector, _num));
        require(ok, "failed");
    }

    //safest - type -checked at compile time, no string risk
    function callWithEncodeCall(uint256 _num) external {
        // abi.encodeCall verifies arg types against the actual function signature at compile time
        // if _num type doesn't match setVars parameter, compile error - not a silent wrong selector
        (bool ok,) = target.call(abi.encodeCall(ITarget.setVars, (_num)));
        require(ok, "failed");
    }
}

/**
SELECTOR COLLISION 

(A selector is only 4 bytes = 2^32 (~4 billion) possible values.
Two completely different function can produce the same 4-byte selector.)

Example (real known collision):
"collate_propagate_storage(bytes16)" and "burn(uint256)"
have the same selector: 0x42966c68

Security concern (collision attack):
In contracts that use selectors for access control or routing, 
an attacker can craft a function with a colliding selector to:
- bypass access control checks
- trigger unintended functions
- exploit proxy dispatch logic

This is a known attack vector in upgradeable proxy contracts. Always check for selector collisions when auditing proxy
dispatch. Tools: https://www.4byte.directory (selector database) 

Security concern (proxy selector clashing):
If the proxy contract itself has functions (like upgradeTo(), admin()) whose selectors clash with the implementation's 
functions, calls intended for the implementation hit the proxy's function instead.
OpenZeppelin's TransparentUpgradeProxy solves this by routing admin calls and user calls through different paths.

*/

contract SelectorCollisionDemo {
    
    // these two function have the same selector: 0x42966c68
    // Solidity won't let you define both in the same contract (compile error)
    // but an attacker could deploy a malicious contract with the colliding one

    // "collate_propagate_storage(bytes16)" -> 0x42966c68
    // "burn(uint256)" -> 0x42966c68

    function getCollisionExample() external pure returns (bytes4, bytes4){
        bytes4 a = bytes4(keccak256("collate_propagate_storage(bytes16)"));
        bytes4 b = bytes4(keccak256("burn(uint256)"));
        // a == b -> true, both are 0x42966c68
        return (a, b);
    }
}

/**
HOW THE EVM ROUTES CALLS (SELECTOR-BASED DISPATCH)

When a call arrives at a contract, the EVM:
1. reads first 4 bytes of msg.data -> function selector
2. compares against all known selectors (compiled into the contract)
3. if match found -> jumps to that function
4. if no match -> triggers fallback() (if exists) 
5. if no fallback -> reverts

This is why:
- calling a non-existent function hits fallback() silently
- wrong selector (typo in encodeWithSignature) hits fallback() silently
- the EVM doesn't care about function names, only selector bytes

INLINE SELECTOR FOR GAS OPTIMIZATION 

Instead of computing selector at runtime with keccak256, you can hardcode the precomputed bytes4 value.
Saves a tiny amount of gas on each call. Only worth it in extremely hot code paths.

Example:
// runtime computation (costs a little gas)
abi.encodeWithSignature("transfer(address,uint256)", to, amount)

// compile-time / inline(cheaper
abi.encodeWithSelector(0xa9059cbb, to, amount)

// best of both (type-safe + compile-time)
abi.encodeCall(IERC20.transfer, (to, amount))

*/

contract InlineSelectorDemo{

    //demonstrating selector computation vs inline 
    function encodeTransferRuntime(address to, uint256 amount) external pure returns (bytes memory){

        //selector computed every call via keccak256
        return abi.encodeWithSignature("transfer(address,uint256)", to, amount);
    }

    function encodeTransferInline(address to, uint256 amount) external pure returns (bytes memory){

        // 0xa9059cbb is precomputed - no keccak256 at runtime
        return abi.encodeWithSelector(0xa9059cbb, to, amount);
    }

}