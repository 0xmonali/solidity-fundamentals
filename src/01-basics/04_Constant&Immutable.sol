// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// key difference:
// constant - value must be known at compile time (hardcoded), cheaper
// immutable - value can be computed or passed in at deployment time
// both are stored in bytecode, not storage - so no SLOAD cost

contract Constant{
    // constant variables - values are fixed forever at the complie time
    // cannot be changed later
    // saves the gas as the value is directly embedded into the contract bytecode by compiler
    // naming convention -  all the variableNames are usually in All_CAPS

    address public constant MY_ADDRESS = 0x742d35Cc6634C0532925a3b844Bc454e4438f44e; //sample address
    uint256 public constant MAX_SUPPLY = 1_000_000; // sample max token supply
    uint256 public constant PRECISION = 1e18; //precision for decimals (commonly used in ERC20 tokens)
}

contract Immutable{
    // immutable variables - values assigned during deployment and assigned once
    // inside the constructor
    // cheaper than normal storage variables
    // slightly more flexible than constants

    address public immutable lastCallerAddr; //address of the deployer/caller
    uint256 public immutable fee; // deployment fee value

    //contructor runs just once during contract deployment
    constructor(uint256 _fee){
        lastCallerAddr = msg.sender; // address deploying the contract
        fee = _fee; //setting immutable fee
    }
}