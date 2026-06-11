// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract ReadWrite{

    uint public num;// state variable stored on the blockchain

    // Write function modifies blockchain state - costs gas
    // SSTORE writes the data on blockchain - one of the most expensive EVM operation
    // Expensive as the blockchain storage is permanent
    // Security concern: anyone can call this function, no access control
    function write(uint _num) public {
        num = _num;
    }

    // Read function - only reads state, usually no gas for local calls
    // SLOAD reads the data from blockcahin storage, cheaper than SSTORE
    function read() public view returns(uint){
        return num;
    }
}