// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
Interfaces:
- contract-like blueprint
- contains only `external` functions without any implementation,curly braces (function signatures)-
- all functions are implicitly `virtual`
- cannot declare a constructor, state variable
- can inherit from other interfaces

NOTE: Unless a function needs to be called from inside a smart contract, 
      it should be external, not public.

Why does it exist?
- Contract A & Contract B are deployed at different addresses
- Contract B wnats to use a function of Contract A, but it just has its address, not source code
- Interface tells the Solidity the shape of what's at that address, so it can call correctly
- Without Interface: Encode the call manually in raw bytes (ugly sometimes) 
 */

//Contract A - deployed separately
contract Calculator {
    function add(uint a, uint b) external pure returns (uint){
        return a+b;
    }
}

//interface - just description, no logic
interface ICalculator {
    function add(uint a, uint b) external pure returns (uint);
}

//Contract B - calls add function from Contract A via interface 
contract CallCalculator{
    function getSum(address calcAddress, uint a, uint b) external view returns (uint){
        ICalculator calc = ICalculator(calcAddress);
        return calc.add(a,b); //staticcall under the hood 
    }
}

/**
Security concern:

- Verify the address:
    *interface does not verify what contract is at that address
    *a malicious contract can pretend to be a legitimate token/oracle
    *common source of fake token attacks
    *check:
        - can users supply arbitrary addresses?

- Check Mutability Matches:
    *interface may decalre a function as view
    *actual implimentation may modify state
    *such calls can revert unexpectedly
    *check:
        - does the interface accurately match the implementation?

- Validate Return Values:
    *A successful interface call can still return bad data
    *Never Blindly trust the return values
    *check:
        - can price be 0?
        - can data be stale?
        - is the return value sanity-checked?

- Watch for interface mismatches
    *interface signature may differ from implementation
    *common with non-standard ERC20 tokens
    *check:
        - Return types
        - Parameter types
        - Funtion signatures

- Every inerface call is an external call
    *control leaves your contract
    *reentrancy becomes possible
    *check:
        - state updated before external call?
        - reentrancy guard present if possible?

- Ensure code exists at the address
    *interface can point to an EOA or empty address
    *calls may suceed unexpectedly with empty returndata
    *check:
        - is address.code.length > 0 verified?
        - is the contract existence trusted?

- Be aware of selector collisions
    *different function signatures can share teh same 4-byte selector
    *particularly dangerous in proxy architectures
    *check: 
        - proxy admin functions
        - upgrade logic
        - fallback routing

- An interface is just a promise about function signatures. 
  not a guarantee that the target address is safe, honest, 
  correctly implementated, or even a contract 
 */