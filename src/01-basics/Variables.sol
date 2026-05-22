// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Variables — There are 3 types of variables in Solidity
// 1. State Variables — stored permanently on-chain in contract storage (expensive)
// 2. Local Variables — exist only during function execution, stored in memory (cheap)
// 3. Global Variables — built-in variables providing blockchain context (no cost)

contract Variables {

    // State Variables:
    // Stored in contract storage on the blockchain permanently
    // Every read = SLOAD opcode, every write = SSTORE opcode
    // SSTORE is one of the most expensive operations in the EVM (~20,000 gas first write)
    // Security: anyone can read state variables even if marked private — storage is public on-chain
    string public text = "Hello";
    uint256 public num = 123;

    // marked payable so we can demonstrate msg.value
    function insideTheFunction() public payable {

        // Local Variables:
        // Only exist during function execution
        // Stored in the memory not in the blockchain storage (cheaper)
        uint256 _i = 456;

        // Global Variables:
        // Built-in variables providing context about blockchain, transaction and caller
        // These are available anywhere without declaration

        // Block globals
        uint256 _timestamp = block.timestamp;
        // Unix timestamp of current blockchain block in seconds
        // Security: miners can manipulate by ~15 seconds
        // Never use for randomness as it can be manipulated
        // Safe for timelocks > 15 minutes

        uint256 _blockNum = block.number;
        // Current block number (block height)
        // Increments by 1 per block (~12 seconds on mainnet)
        // Sometimes used for randomness — also manipulable, never safe for randomness

        uint256 _blockGasLimit = block.gaslimit;
        // Maximum gas allowed in current block
        // Security: DoS attacks can exploit contracts that loop based on gas assumptions

        address _blockCoinbase = block.coinbase;
        // Address of the miner/validator who mined this block
        // Security: never use for access control — miners can manipulate this

        uint256 _blockBaseFee = block.basefee;
        // Base fee per gas of current block (introduced in EIP-1559)
        // Useful for gas price aware contracts

        uint256 _blockChainId = block.chainid;
        // ID of the current chain
        // mainnet = 1, sepolia = 11155111, polygon = 137
        // Security: always include chainid in signatures to prevent cross-chain replay attacks
        // EIP-712 uses chainid for this exact reason

        // Message globals:
        address _sender = msg.sender;
        // Address of the immediate caller of this function
        // Security: in delegatecall, msg.sender stays as original caller
        // Never confuse with tx.origin

        uint256 _value = msg.value;
        // Amount of Ether sent with this call in Wei
        // Only non-zero if function is marked payable
        // Security: always validate msg.value in payable functions

        bytes memory _data = msg.data;
        // Full calldata of the transaction — includes function selector + arguments
        // First 4 bytes = function selector (keccak256 of function signature)

        uint256 _gasLeft = gasleft();
        // Remaining gas at point of this call
        // Security: never make logic depend on gasleft() — manipulable by caller

        // Transaction globals:
        address _origin = tx.origin;
        // Original EOA that initiated the transaction
        // Security: NEVER use tx.origin for authorization
        // If contract A calls contract B, tx.origin = user, msg.sender = contract A
        // Phishing attacks exploit tx.origin checks — always use msg.sender instead

        uint256 _gasPrice = tx.gasprice;
        // Gas price of the current transaction in Wei
        // Varies per transaction — not reliable for logic
    }
}