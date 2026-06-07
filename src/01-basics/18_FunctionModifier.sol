// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
/**
Funtion Modifier:

A reusable block of code that wraps around a function
Used to runs some code before (and/or after) the function body

The `_` (underscore) is a placeholder for th function body where the actual function code runs

 */

contract FunctionModifier {
    address public owner;
    bool public paused;
    uint public count;

    constructor(){
        owner = msg.sender;
    }

    //modifier 1 (only Owner can call the function) (pre-check)
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");// this runs first on execution of a function wrapped by this modifier
        _; // here the function code block is executed 
    }

    //modifier 2 (block calls when paused) (pre-check)
    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    //modifier 3 (validate input) (pre-check)
    modifier validAmount(uint amount) {
        require(amount > 0 && amount <= 1000, "Amount out of range"); 
        _;       
    }

    //modifier 4 (logCall)
    modifier logCall() {
        count++;
        _;
    }

    //modifier 5 (post check: verify state after execution)
    modifier checkCounterIncremented(uint _prevCount){
        _;
        require(count == _prevCount + 1, "Counter not incremented");
    }

    //functions using the modifiers
    function pause() external onlyOwner{
        paused = true;
    }

    function unpause() external onlyOwner{
        paused = false;
    }

    function someAction(uint amount) external onlyOwner whenNotPaused validAmount(amount) logCall checkCounterIncremented(count){
        //logic here
    }

/**
Security concerns:

- Modifier order matters
- post-checks with state changes before validation are a reentrancy-adjacent risk.
- CEI violation in function body: if the external calls happens before state updates, reentrancy risk - independent of modifiers
- if a modifier ever makes an external call, the function body runs in the middle of that call chain,
  reentrancy risk.
- onlyOwner with no transfer mechanisms: no tranferOwnership can lead to contract to permanently bricked, making pause, unpause unable to work
- always trace internal call paths, modifiers only guard the function they are on. An internal function has zero protection
- pause mechanism with no event emission: state changes without events are flagged, events covered in next contract (Events&Logs.sol) 
  
 */

}