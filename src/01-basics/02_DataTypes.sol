// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// DataTypes — demonstrates all primitive types in Solidity
// Key insight: choosing the right type size matters for gas optimization
// uint256 is actually the most gas efficient despite being largest —
// EVM works in 32-byte (256-bit) words natively, smaller types need extra operations

// DEFAULT VALUES — every uninitialized variable has a default in Solidity
// unlike some languages where uninitialized variables are undefined/null
// Solidity always initializes to zero-equivalent:
// uint/int = 0 | bool = false | address = address(0) | bytes = 0x | string = "" | enum = first member (index 0)

contract DataTypes {

    // --- Unsigned Integers ---
    // Range: 0 to (2^n - 1)
    // uint8 max = 255, uint256 max = 115792089...
    // Security: overflow reverts in 0.8+, silently wrapped before 0.8
    // Default: 0
    uint8 public smallUint;      // 0 to 255
    uint16 public medUint;       // 0 to 65,535
    uint32 public uint32Val;     // 0 to 4,294,967,295
    uint128 public uint128Val;
    uint256 public largeUint;    // most common, gas efficient on EVM
    uint public defaultUint;     // uint is alias for uint256

    // --- Signed Integers ---
    // Range: -(2^n / 2) to (2^n / 2 - 1)
    // int8 range: -128 to 127
    // Security: same overflow protection as uint in 0.8+
    // Default: 0
    int8 public smallInt;        // -128 to 127
    int16 public medInt;
    int32 public int32Val;
    int64 public int64Val;
    int128 public int128Val;
    int256 public largeInt;
    int public defaultInt;       // int is alias for int256

    // --- Boolean ---
    // Stored as uint8 under the hood (0 or 1)
    // Default: false
    bool public isActive;

    // --- String ---
    // Dynamically sized UTF-8 encoded data
    // Expensive to store on-chain — avoid storing large strings in state
    // Default: "" (empty string)
    string public word;

    // --- Address ---
    // 20 bytes — holds an Ethereum wallet or contract address
    // address payable can receive Ether, plain address cannot
    // Default: address(0) — the zero address 0x0000000000000000000000000000000000000000
    // Security: always check msg.sender != address(0) in critical functions
    // sending funds to address(0) burns them permanently — common critical bug
    address public walletAddr;

    // --- Enum ---
    // Internally stored as uint8 starting from 0
    // Mon = 0, Tues = 1, ... Sun = 6
    // Default: first member — Days.Mon (index 0)
    // Security: enums revert on invalid value assignment in 0.8+
    enum Days { Mon, Tues, Wed, Thurs, Fri, Sat, Sun }
    Days public dayOff = Days.Sun;
    Days public workDay;         // defaults to Days.Mon (0)

    // --- Bytes ---
    // bytes — dynamic, like string but for raw binary data
    // bytes2, bytes32 etc — fixed size, cheaper than dynamic bytes
    // bytes32 is very common for hashing (keccak256 returns bytes32)
    // Default: dynamic bytes = 0x (empty) | fixed bytes = 0x0000...
    bytes public dynamicBytes = "Hello Auditor!";
    bytes2 public fixedBytes = 0x1234;
    bytes32 public hashVal;      // defaults to 0x0000000000000000000000000000000000000000000000000000000000000000
}