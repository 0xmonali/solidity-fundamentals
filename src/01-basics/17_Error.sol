// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
In solidity when something wents wrong, EVM needs to:
- stop the execution, Undo all the states and tell the caller what went wrong 
this is called revert.

There are 3 mechanisms in solidity to handle errors
- Require
- Revert
- Assert

Require:
Checks the conditions before doing anything 
- conditions false, it stops and reverts 
- conditions true, execution continues normally 

syntax - require(condition, "error message");

When to use Require?
- when the failure is the caller's fault (wrong inputs, not enough balance, wrong permissions, wrong time, external conditions not met)


Revert:
Does same thing as require(stops + undoes everything) but
it gives more control, the developer decide when to trigger it, with no condition syntax

old style-
revert("some_error_string");

new style (custom error)-
error MyError(uint given, uint max);
if (given > max) revert MyError(given, max);

Why custom errors are better?

- in old way the string is stored in bytecode, costs gas to store - expensive!
- in new way just 4 bytes + encoded params are stored - gas efficient - cheap comparatively!

Custom errors are ~50% cheaper in gas than string messages.
Custom error migration is a  valid gas optimisation finding.

Assert:
Check things that should mathematically never be false 
Its neither for user input not external condition 
Its purely to catch the developer's own bugs 

syntax - assert(condition)

condition should always be true
if false = Developers bug

Key difference from require:
- require fails: refunds remaining gas (caller's fault, expected)
- assert fails: burns All remaining gas (developer's bug, expected)

assert failures produce a Panic(uint256) error with a code
eg., Panic code: 0x01, Meaning: assert failed
Panic code: 0x11, Meaning: Arithmetic overflow/underflow

*/
contract Require {
    uint public age; //state variable
    function setAge(uint _age) public {
        require(_age > 0, "Age must be positive"); // require condition 1
        require(_age <= 150, "Age too large");// require condition 2
        //updating the state variable with the entered value
        age = _age; // reaches here when the above 2 conditions are passed
    }
}

/**
what happens step by step in the Require contract:

if user calls setAge(0):
- require condition 1: false
- EVM reverts immediately
- age is not changed
- caller gets error: "Age must be positive"
- remainig gas is REFUNDED

if user setAge(25):
- require (25 > 0): true
- require (25 <= 150): true
- age = 25
- transaction succeeds
 */


contract Revert{
    //custom errors are defined at the top of the contract
    error NotOwner (address caller, address owner);
    error ValueOutOfRange (uint given, uint min, uint max);

    address public owner;
    uint public val;

    //constructor runs once, duting the contract deployment
    constructor(){
        owner = msg.sender;
    }
    
    function onlyOwnerAction() public{
        if (msg.sender != owner) {
            revert NotOwner(msg.sender, owner);
        }
        //do the action
    }

    function setValueInRange(uint _val) public{
        if (_val < 10 || _val > 500){
            revert ValueOutOfRange(_val, 10, 500);
        }
        //proceed
    }
}

contract Assert{
    uint public totalSupply = 1000;
    mapping (address => uint) public balances;

    constructor(){
        balances[msg.sender] = 1000;
    }

    function transfer(address to, uint amount)  public {

        //require - caller's fault (input validation)
        require(amount>0, "Zero amount");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(to != address(0), "Zero address");

        uint senderBefore = balances[msg.sender];
        uint receiverBefore = balances[to];

        balances[msg.sender] -= amount;
        balances[to] += amount;

        //assert - our invariant:  total must never change
        //Invariant meaning - A property that always must be true
        //"no matter what, sender lost exactly what receiver gained"

        assert(balances[msg.sender] + balances[to] == senderBefore + receiverBefore);

        //assert - another invariant: no one's balance exceeds total supply
        assert(balances[msg.sender] <= totalSupply);
        assert(balances[to] <= totalSupply); 
    }
/**
Security concerns:

Require:
- Missing access control: no require(msg.sender == owner) gives access of privileged functions to anyone
- wrong condition directions (< instead of >, or vice-versa)
- require inside unbounded loop - one failing address blocks the entire batch forever
- using .send() or .transfer(): 2300 gas limit causes silent failures for contract recipients 
- tx.origin check: weak guard taht breaks multisigs and enables phishing attacks 
- locks set after require: reentrancy window exists between the check and lock being set
- no error message makes it impossible to to debug 
- missing zero-address checks: sending ownership to address(0) permanently bricked (unusable)

Revert:
- Unchecked .call() return value: transfer silently fails but the contract thinks it successfull
- DoS via revert in refund: malicious contract's receive() reverts, permanently blocking that user's refund
- Swallowing external revert reason- real failure cause from call contract is lost
- Sensitive data in custom error params- internal balances or prices visible to anyone reading revert data
- revert reason visible in mempool- MEV bots read failed tx data to front-run your users
- blanket revert in receive()- blocks all ETH sends including legitimate ones, permanently locking funds

Assert:
- assert on user input: burns all remaining gas instead of gracefully refunding it
- user input reaching assert: attacker crafts inputs to force assert failure and grief gas
- Pre -0.8 overflow assert: overflowed value triggers assert which burns all gas instead of reverting clean
- Missing assert on critical invariant - critciacallmath is assumed correct but never enforced o-chain
- Assert in called contract: a downstream assert failure burns gas for your entire call chain too
- assert in constructor: fialed deployment burns deployer's gas without graceful fallback

*/

}