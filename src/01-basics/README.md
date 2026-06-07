# 01 — Counter

My first Solidity project written from scratch.

## What it does

A simple on-chain counter that can be incremented and decremented by anyone.

## Concepts demonstrated

- State variables and how they persist on-chain between transactions
- `public` visibility and auto-generated getters
- `view` functions — read-only, no gas cost when called externally
- State mutation functions — write to storage, cost gas
- Solidity 0.8+ underflow/overflow protection

## Security insight

`dec()` will automatically revert if `count == 0` because Solidity 0.8+
has built-in underflow protection. Before 0.8, this would silently wrap
around to `type(uint256).max` — one of the most common critical bugs in
early smart contracts.

## Gas insight

`count += 1` costs slightly more gas than `unchecked { count += 1; }`
because the compiler adds overflow checks. For a counter where overflow
is practically impossible, `unchecked` would be the gas-optimal choice.

## Reference

[Solidity By Example — Counter](https://solidity-by-example.org/first-app/)