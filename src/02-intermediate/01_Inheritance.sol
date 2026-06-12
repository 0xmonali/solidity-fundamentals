// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
Inheritance:

- An object oriented programming feature that allows one contract 
  to reuse the code of another contract

Clarification (Compile-time mechanism):

Two different meaning of contract
- Solidity Contract (source code)
- Smart Contract (deployed bytecode)

- inhertance only occurs at source code level during compilation
- a deployed contract cannot be inherted or modified by another 
  deployed contract 

Types of Inhertance:
- single inheritance
- multiple inheritance
- multilevel inheritance
- hierarchial inheritance
- hybrid inheritance

Child contract inherits:
- functions (except private)
- state variables
- modifiers
- Events (only internal/ public members)

Child contracts can directly emit the events declared in 
Base and use modifiers of Base without re-declaring 

When the child contract is deployed, parent constructor is 
automatically executed (if exists) and the child must provide the 
required constructor arguments

`virtual` - this function can be overriden by a child
`override` - this function is overriding a parent's virtual function
`super` - call the next function in the MRO chain
          (not necessarily the immediate parent in the multi-inheritance)
*/

contract Animal{
    function speak() public pure virtual returns (string memory) {
        return "..."; 
    }

    function breathe() public pure returns(string memory) {
        return "inhale/exhale";
    }

    // speak() can be overriden by child 
    // breathe() cannot be overriden by the child 

}

contract Dog is Animal{

    // `override` required - omitting it - compiel error
    // ` virtual ` \again allows further overriding by child, without `virtual` the child cannot override
    // Security concern: Missing virtual on override for further childs - breaks the intended hook chains

    function speak() public pure virtual override returns (string memory){
        return "Woof";
    }
}

contract GoldenRetriver is Dog{
    function speak() public pure override returns(string memory){
        //super.speak() calls -> Dog.speak() in single inheritance case
        // in nulti- inheritance, super walks the MRO (discussed later)
        return string.concat(super.speak(), " Woof"); 
    }
}

//Constructor and initialization 
//Order of execution: most-base constructor -> ... -> most-derived last


contract Base{
    uint public baseVal;

    constructor (uint _val) {
        baseVal = _val;
        //runs first 
    }
}

contract Mid is Base{
    uint public midVal;

    constructor(uint _val) Base(_val*2) {
        midVal = _val;
        //runs second
    }
}

contract Child is Mid{
    uint public childVal;

    constructor (uint _val) Mid(_val) {
        childVal = _val;
        //runs third
        //here: baseVal = _val * 2, midVal = _val, childVal = _val
    }
}

/**
Security concerns regarding constructor:

- Incorrect constructor chaining can leave critical state variables improperly initialized
- Solidity catches completely missing constructor arguments at compile time.
- Focus on whether teh correct values are propagated through multi-level inheritance chains and whether
  initialization occurs in the expected order 
 */


/**
C3 LINEARIZATION (MRO)

MRO - Method Resolution Order

Purpose:
- Determines which parent implementation is used when multiple inherited contracts define the same function

e.g., contract D is B, C
The search order is  D -> C -> B -> A , rightmost parent gets priority 

- super follows the next contract in MRO
- super doesn't mean the immediate parent

Security concern:
- unexpected function resolution or incorrect use of super can lead to logic and access-control bugs
 */

contract P {
    function ping() public pure virtual returns (string memory){
        return "P";
    }
}

contract Q is P{
    function ping() public pure virtual override returns (string memory){
        return string.concat("Q->", super.ping());
    } 
}

//MRO of R: R->Q->P
//super.ping() in R calls Q.ping() (rightmost in `is` list = highest priority)
//super.ping() in Q then calls P.ping()
//Full trace: R->Q->P

contract R is P, Q{
    function ping() public pure override (P, Q) returns (string memory){
        return string.concat("R->", super.ping());
        // super here = Q (right most in MRO)
        // Q's super = P
        // result: R->Q->P
    }
}
/**
Security concern:

- MULTI-INHERITANCE REQUIRES EXPLICIT override (...)
  Solidity requires listing all parents that define this function.
  ommiting any -> compile error. Good safety net - but semantics of the super chain still need manual tracing 

- MRO AMBIGUITY BUG
  `super` follows the final MRO, not the direct parent, so adding/reordering inherited contracts can silently
   change which executed and break critical logic
 */

// DIAMOND PROBLEM & COOPERATIVE SUPER

/**
MRO of Diamond (is left, right): Diamond -> Right -> Left -> Root
each `super` call walks one step forward in this chain
this is cooperative super - every contract in the chain
participates, not just teh immediate parent.
 */

contract Root{
    event Log(string msg);

    function action() public virtual{
        emit Log("Root");
    }
}

contract Left is Root{
    function action() public virtual override {
        emit Log("Left");
        super.action(); //calls root
    }
}

contract Right is Root{
    function action() public virtual override{
        emit Log("Right");
    }
}

//Calling Diamond.action() emits: Left -> Right -> Root

/**
Security concern: COOPERATIVE SUPER - UNEXPECTED EXECUTION ORDER (SUPER CHAIN EXECUTION RISK)
- `super` executes every override in the MRO chain, so inherited guards and logic may run multiple times or 
  unexpectedly if developers assume it only calls the immediate parent
*/

contract Diamond is Left, Right{
    function action() public override(Left, Right){
        emit Log("Diamond");
        super.action(); //Right -> Left ->Root (MRO order)
    }
}

//STATE VARIABLE SHADOWING

/**
Child can declare a variable with same name as the parent
this does not override the parent variable, it creates a new, separate storage slot
Both exist. Both are accessible. Via different contexts.

Security concern:
- This is one of the most insideous inheritance bugs
- Solidity 0.6+ emits a COMPILEER WARNING, but not an error
- The protocol appears to work but has inconsistent accounting:
  parent logic reads slot N, child logic reads slot N+1
  Run: slither --detect shadowing-state to catch this
 */

contract ShadowParent {
    uint public balance = 100; //storage slot 0

    function getBalance() public virtual view returns (uint){
        return balance; // read slot 0
    }
}
//Shadowing is disallowed in Solidity 0.6, the following will not compile as it creates ambiguity

/**  
contract ShadowChild is ShadowParent{

    //creates a new variable at slot 1. Does not touch slot 0
    //ShadowParent.balance (slot 0) = 100, unchanged
    //ShadowChild.balance (slot 1) = 200, separate

    uint public balance = 200;

    function getBalance() public override view returns (uint) {
        return balance; //read slot 1 = 200
    }

    function getParentBalance() public view returns (uint){
        return ShadowParent.balance; //explicit qualifier -> slot 0 = 100
    }
}

*/

contract ShadowChild is ShadowParent{

    //this is the correct way to override inherited state variables
    constructor(){
        balance = 200;
    }

    //ShadowChild.getBalance returns 200
}

//MODIFIER INHERITANCE AND OVERRIDE

/**
Modifiers are inherited like functions
they can also be - virtual and override

Security concern (VIRTUAL MODIFIER OVERRIDE):
- A child contract can override a virtual modifier and weaken 
  or remove inherited security checks, potentially exposing 
  privileged function to unauthorized users.
*/

contract ModParent {
    address public admin;
    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin () virtual{
        require(msg.sender == admin, "not admin");
        _;
    }

    function sensitiveAction() public virtual onlyAdmin returns (bool) {
        return true;
    }
}

contract ModChildBad is ModParent {
    modifier onlyAdmin() override {
        //check silently removed - anyone can call sensitiveAction()
        _;
    }
}

contract ModChildGood is ModParent{
    bool public emergencyStop;

    modifier onlyAdmin() override{
        require(msg.sender == admin, "not admin"); //re-implemented parent check
        require(!emergencyStop, "emergency stopped"); // adding extra logic
        _;
    }
}

//PRIVATE VS INTERNAL IN CHILD ACCESS

/**
`private` :
only defining contract
children cannot see or call it
child cannot override private functions
DOES NOT mean secret on-chain: eth_getStorageAt reads everything

`internal` :
defining contract and all derived contracts
the 'protected' equivalent in oop
children can call and override the internal functions

Security concern (Confusion in proxy pattern):

if a  proxy's upgarde authorization function is `private` instead of `internal virtual` , 
a child contract thinks its overriding access control but isn't - the parent's (possibly weaker)
checks still runs silently
 */

contract Visibilty {
    uint private _privateVar = 1; //slot 0 -> only this contract 
    uint internal _internalVar = 2; //slot 1 -> this + child 

    function _privateHelper() private pure returns (string memory){
        return "private";
    }

    function _internalHelper() internal virtual pure returns (string memory){
        return "internal";
    }
}

contract VisibiltyChild is Visibilty{
    function test() public view returns(uint){
        // _privateVar & _privateHelper() -> compiler error
        return _internalVar; // accessible
    }

    function _internalHelper() internal pure override returns (string memory){
        return "overriden";
    }
}

//ABSTRACT CONTRACTS AND EMPTY HOOKS

/**
Abstract contract defines virtual functions with empty bodies ("hooks")
Child contract sare expected to override them to add behaviour
if a child forgets to override, the empty default silently runs - no error

what is a hook?
- it is a function that runs before/after some action

Security concern (empty hook default)
- two siblings, both override the same hook,
  if either one forgets to call super._hook(), the other's logic is skipped.
  real example: ERC20Pausable and ERC20Capped both override _beforeTokenTransfer,
  if Pausable's override doesn't call super, the cap check is silently skipped!
  Tokens tarnsfer even when pauseed. Cap is never enforced.
 */


abstract contract HookBase{
    //empty default - child is expected to override this
    //if not overriden, this empty version runs silently

    function _beforeAction(address caller) internal virtual{}

    function doAction (address caller) public {
        _beforeAction(caller); //hook - child adds checks here 
        // core logic
    }
}

//safe - overrides hook and call superto preserve the chain

contract HookChildA is HookBase{
    bool public paused;

    function _beforeAction (address caller) internal override virtual{
        require(!paused, "paused");
        super._beforeAction(caller); //passes control down the chain
    }
}

//unsafe : overrides hook but skips super- breaks the chain

contract HookChildBad is HookBase{
    uint public maxCalls = 10;
    uint public callCount;

    function _beforeAction (address caller) internal override{
        require(callCount < maxCalls, "limit reached");
        callCount++;
        // missing super._beforeAction() - if another sibling exists in MRO,
        // its check is silently skipped
    }
}

/**
Multi-level: both A and B override the hook 
MRO of combined: Combined -> HookChildA -> HookBase
if HookChildA calls the super, both checks run, else the B's check is SKIPPED
 */

contract Combined is HookChildA {
    function _beforeAction(address caller) internal override{
        require(caller != address(0), "zero address");
        super._beforeAction(caller); //calls HookChildA._beforeAction which calls the HookBase._beforeAction

    }
}