// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Counter — simplest stateful contract
// Demonstrates: state variables, view functions, state mutation
// Security note: Solidity 0.8+ automatically reverts on underflow,
// so dec() will revert if count is already 0 — no explicit check needed.
// Before 0.8 this would silently wrap to type(uint256).max — a critical bug.

contract Counter {

    // State variable stored permanently on-chain in contract storage
    // 'public' auto-generates a getter — no need for a separate get() function
    // but we write it explicitly here to practice view functions
    uint256 public count = 0;

    // view — reads state but does not modify it, costs no gas when called externally
    function get() public view returns (uint256) {
        return count;
    }

    // Modifies state — costs gas because it writes to storage (SSTORE opcode)
    // count += 1 has overflow protection built in (0.8+)
    // Gas tip: unchecked { count += 1; } would save ~40 gas if overflow is impossible
    function inc() public {
        count += 1;
    }

    // Will automatically revert if count == 0 (underflow protection, 0.8+)
    // Before 0.8: count would wrap to 115792089...(max uint256) — silent critical bug
    function dec() public {
        count -= 1;
    }
}