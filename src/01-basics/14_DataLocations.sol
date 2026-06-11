// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
Variables are declared as either storage, memory or calldata
to explicitly specify the data locations.

Storage-

Persists on-chain data
Costly as SLAOD and SSTORE operationos are done
Every state variable is storage by default

A storage pointer without assignment defaults to slot 0-
silently corrupting whatever state variable lives there

Returning a storage ref from a function hands the caller 
a live key to teh contract's state -  any modification through that ref
mutates the chain state directly


Memory- 

Temporary
Exists during a Function call, wiped out after
cheaper than storage

Assigning a struct from the mapping to memory makes a copy,
mutations do not persists - most  common silent bug in contracts

memory arrays must be fixed sized when declared ,
new uint[](n) - cannot push to a memory array


Calldata-

Read-only
Exists in the transaction input data
Cheapest of all - no copy made

Only available on external functions,
cannot use calldata in public or internal functions.

Using memory instead of calldata for external array
parameters silently copies the entire array - gas wastage 
linearly to array size 


Edge cases-

Nested storage passed into internal storage -
every writes goes on-chain 

delete on a storage struct sets zero in every field -  Does not 
free the slot or refund full gas post-EIP-3529

Copying a large memory array in a loop hits the quadratic memory 
expansion cost - gas grows fasters than linearly past ~724 bytes

*/

contract DataLocations{
    uint[] public arr; //slot 0
    mapping(uint => address) map; //slot 1
    
    struct MyStruct { //slot 2
        uint foo;
    }

    mapping (uint => MyStruct) myStructs; //slot 3

    //Storage data location used below

    function f() public {
        _f(arr, map, myStructs[1]);
        MyStruct storage myStruct = myStructs[1]; // reference, not copy (1 refers to the key value 1)
        MyStruct memory myMemStruct = myStructs[0]; 

    }

    function _f(
        uint[] storage _arr,
        mapping (uint => address) storage _map,
        MyStruct storage _myStruct
    ) internal {
        // any write here directly make on-chain modifications
        _arr.push(1);
        _myStruct.foo = 99;
    }

    /* Invalid: 
     
        function f(storage _arr,
        mapping (uint => address) storage _map,
        MyStruct storage _myStruct) public {

        //

        }
        
        Storage parameters are only allowed for internal/private functions.
        A public/external function cannot accept `storage`
        parameters because external callers cannot provide 
        references to contract storage.

    */ 

   //Memory data location used below
    function g(uint[] memory _arr) public pure returns (uint[] memory) {
        _arr[0] = 777; // modifies only local copy
        return _arr;
    } 

    //Calldata data location used below
    function h(uint[] calldata _arr) external pure returns (uint) {
        return _arr.length; // calldata is immutable , only CALLDATALOAD and CALLDATACOPY exists
    }

}