// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Gas - measurement of computational work on Ethereum
// Every operation in solidity costs gas
// Users pay gas fees in Ether(ETH)
// Prevents : Spam transaction, malicious infiinte loop, network abuse
// Real world - Fuel, Ethereum - Gas
// Real world - Vehicle, Ethereum - Transaction
// Real world - longer trip = more fuel, Ethereum - longer computation = more gas

// Gas formula : Gas fee = Gas used x (Base fee + Priority fee)
// Base fee - Minimum fee required, decided automatically by the Ethereum, gets burned(destroyed) and changes depending on network traffic
// Priority fee - Extra money paid to validators, helps transaction get processed faster

// Gas Limit - Maximum gas users allow the transaction to consume, prevents infinite computation
// if gas limit lower than required - transaction fails/reverts
// if gas limit higer than required - unused gas is refunded

// For complex Smart Contracts - complex heavy computation
// Failed transaction of such contracts - gas may still be consumed as some computional work was already done

//Rise in Gas fees: many people using ETH simultaneously, network congests, heavy computation
// Higher the demand -> users compete using higher tips

contract Gas {

    uint256 public i = 0;

    // this function will run until it runs out of gas and reverts
    // demonstrates: out of gas error, infinite loop danger
    function forever() public {
        while (true) {
            i += 1;
        }
    }
}

contract GasSaver {

    // demonstrates cheap vs expensive patterns
    // uint256 is cheaper than uint8 on EVM - EVM uses 32 byte slots natively
    uint256 public cheapVar;   // cheaper to read/write
    uint8 public expensiveVar; // needs extra conversion, slightly more gas

    // calldata is cheaper than memory for read-only function inputs
    // memory creates a copy, calldata reads directly from transaction data
    function withMemory(uint256[] memory arr) public pure returns (uint256) {
        return arr.length;
    }

    function withCalldata(uint256[] calldata arr) public pure returns (uint256) {
        return arr.length; // cheaper - no copy made
    }

    // caching state variables saves gas
    // each SLOAD costs 2100 gas (cold) or 100 gas (warm)
    // reading a local variable costs ~3 gas
    function expensiveLoop(uint256 n) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < n; i++) {
            total += cheapVar; // SLOAD on every iteration - expensive
        }
        return total;
    }

    function cheapLoop(uint256 n) public view returns (uint256) {
        uint256 total = 0;
        uint256 cached = cheapVar; // one SLOAD, then use local var
        for (uint256 i = 0; i < n; i++) {
            total += cached; // cheap local read every iteration
        }
        return total;
    }
}