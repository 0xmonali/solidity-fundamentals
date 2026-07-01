// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
Topic: Try / Catch

BASICS(what & why):

Normally, if a function call inside your contract reverts, your ENTIRE transaction reverts 
too - nothing you did, including earlier storage writes in the same call, survives. try/catch 
lets you call an EXTERNAL contract (or run `new Contract(...)`) and, if THAT call reverts, 
catch the failure and keep your own transaction going instead of also reverting. Think of it 
like try/catch in Javascript and Python, but with an important restriction: it ONLY works on 
external calls and contract creation - never on internal function calls or plain expressions.

This file builds from "how do I keep running after an external call fails" up to the audit concerns:
state inconsistency, gas griefing of the catch handler, and "we assumed this external dependency 
never fails."
 */

contract Dependency {
    /**
    A contract whose behaviour we don't fully control - it might revert with a reason string,
    panic, or revert with a custom error.
     */

    function mayFailWithReason(uint256 x) external pure returns (uint256) {
        require(x != 0, "Dependency: x cannot be zero");
        return 100/x;
    }

    function mayPanic(uint256[] memory arr, uint256 index) external pure returns (uint256) {
        return arr[index]; // revert with Panic(0x32) if index out of bounds
    }

    error CustomFailure(string reason);

    function mayFailCustom(bool fail) external pure returns (uint256) {
        if (fail) revert CustomFailure("custom error triggered");
        return 1;
    }
}

contract NewContractThatMayRevert {
    constructor (uint256 x) {
        require (x > 0, "constructor: x must be positive");
    }
}

contract TryCatchExample {
    Dependency public dep = new Dependency();

    event SuccessLog(uint256 value);
    event FailureLog(string reason);
    event PanicLog(uint256 errorCode);
    event LowLevelFailureLog(bytes data);

    /**
    1. Catching a `require`/`revert("reason")` style failure

    WHAT THIS IS:
    `catch Error(string memory reason)` specifically matches reverts that carry a string
    reason - i.e. require(cond, "x") or revert("x"). This is the ONLY catch clause matched 
    by that style. 
     */

    function tryMayFailWithReason(uint256 x) external {

        try dep.mayFailWithReason(x) returns (uint256 result) {
            emit SuccessLog(result);

        } catch Error(string memory reason){
            emit FailureLog(reason);
            
            /**
            Security concern:
            catching and logging is fine IF nothing before this try block depended on 
            mayFailWithReason actually succeeding. Always check: did this contract already 
            write to storage, transfer funds, or update an invariant BEFORE this try call, 
            assuming success? try/catch only undoes the CALLEE's state changes, never the 
            caller's own prior writes. 
             */
        }
    }

    /**
    2. Catchin a Panic (assert failures, overflow, OOB array, etc.)

    WHAT THIS IS:

    Solidity 0.8+ throws a Panic(uint256) for internal errors - failed assert(), arithmetic 
    over/underflow, division by zero, out-of-bounds array/array index, popping an empty array,
    etc. Each has a distinct error code (0x01 assert, 0x11 overflow, 0x12 div-by-zero, 0x32 out-of-bounds, ...).
     */

    function tryMayPanic(uint256[] memory arr, uint256 index) external {
        try dep.mayPanic(arr, index) returns (uint256 result) {
            emit SuccessLog(result);

        } catch Panic(uint256 errorCode) {
            emit PanicLog(errorCode);

            /**
            Security concern: silently swallowing a Panic can mask real bugs in the dependency contract 
            (e.g. a broken invariant causing constant overflow) rather than surfacing them. Ask during 
            review: is catching Panic here intentional resilience, or is it hiding a bug that should 
            actually halt execution?
             */

        }
    }

    /**
    3. Catch-all for custom errors and anything else (raw bytes)

    WHAT THIS IS:

    custom errors (`error Foo(...)`) don't match `catch Error(string)` because they're not a 
    a plain string revert - they ABI-encode their own selector + args. They land here, in the
    generic `catch (bytes memory lowLevelData)` clause, along with any revert that doesn't match 
    the more specific clauses above.

     */
    
    function tryMayFailCustom(bool fail) external {
        try dep.mayFailCustom(fail) returns (uint256 result) {

            emit SuccessLog(result);

        } catch (bytes memory lowLevelData) {
            
            emit LowLevelFailureLog(lowLevelData);

            /**
            Security concern (return/revert bomb):

            a malicious or buggy dependency can revert with an enormous bytes payload here,
            forcing this caller to spend significant gas just copying that data into memory- 
            potentially causing the CATCH BLOCK ITSELF to run out of gas, which means even your 
            fallback logic doesn't execute. This happens because without a gas cap on the call,
            the callee controls how much revert data comes back, and therefore how much memory 
            allocation cost the caller must pay. If you call untrusted contracts this way, consider 
            bounding gas with {gas: ...} on the call. 
             */
        }
    }

    // 4. try/catch on contract creation

    function tryDeploy(uint256 x) external returns (address) {
        try new NewContractThatMayRevert(x) returns (NewContractThatMayRevert c) {
            return address(c);
        } catch {
            /**
            Bare `catch` with no parameters - catches everything but gives you no information 
            about WHY it failed. Acceptable only when the caller genuinely doesn't need the reason.
             */
            return address(0);
            /**
            Security concern:
            returning address(0) on failure is only safe if every caller of tryDeploy actually
            checks for the zero address afterward. An audit should trace every call site of a function
            like to confirm the failure signal is never silently ignored downstream.
             */
        }
    }

    // 5. A realistic audit-relevant anti-pattern: oracle try/TryCatchExample

    uint256 public lastKnownPrice;

    function updatePriceFromOracle(Dependency oracle, uint256 input) external {
        try oracle.mayFailWithReason(input) returns (uint256 price) {
            lastKnownPrice = price;
        } catch {
            
            /**
            Security concern (HIGH) : 

            Silently keeping the OLD price on any oracle failure means a temporarily broken/manipulated
            oracle doesn't halt teh protocol - it just causes the protocol to keep operating on a STALE 
            price. Depending on what lastKnownPrice gates (liquidations, swaps, collateral checks), this 
            can be directly exploitable. Crucially, the catch branch is not only triggered by accidental 
            failures - an attacker can deliberately engineer an oracle revert (for example via a flash 
            loan that destabilizes the underlying pool the oracle reads from) to force execution into 
            this catch path and operate against a known stale price. A safer pattern is often to revert 
            the whole transaction on oracle failure, or to require a fresh price within a max staleness
            window, rather than silently falling back. 
             */
        }
    }


}