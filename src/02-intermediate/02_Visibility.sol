// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
Visibility:
Every function and state variable in solidity has a visibilty specifier
- it controls who can call the function or read taht variable

There are 4 visibility levels:
- `public` : anyone (EOA, other contracts) and internally
- `private` : only this contract , not even the child
- `internal` : this contract + any contract taht inherits from it
- `external` : only form outside - cannot be called internally (directly) 

not declaring any visibility specifier - public by default
*/

contract VisibiltyBasics{
    //State variables visibility

    //public: auto generates a getter function 
    uint public publicNumber =10;

    //private: accessible by this contract only, not by the children
    uint private privateNumber = 20;

    //internal: accessible by this and child contracts
    uint internal internalNumber = 30;

    //NO EXTERNAL STATE VARIABLE IS VALID; ONLY THE FUNCTIONS CAN BE EXTERNAL


    //Functions visibility

    //public function: callable from anywhere
    function getPublic() public view returns (uint){
        return publicNumber;
    }

    //private function: only callable inside this contract
    //underscore (_) at the beginning of a private fucntion is naming convection
    //- underscor is just a low-level helper function, not a part of public API, just increases readability 
    //It means - the function is meant to be called from within the contract or inherited contracts 
    function _getPrivate() private view returns (uint){
        return privateNumber;
    }

    //internal fucntion: callable inside this contract and the child
    function _getInternal() internal view returns (uint){
        return internalNumber;
    }

    //external function: only callable from outside (not internally)
    function getExternal() external view returns(uint){
        return publicNumber;
    }

    //calling a private function inside a private function
    function _usePrivate() private view returns(uint){
        return _getPrivate();
    }

    //Calling an external internally like this - compilation error
    //function bad() public view returns (uint){
    //    return getExternal(); 
    //}

    //right way of calling an external function from inside the same contract
    //use - this.externalfunctionName() : this makes an external call - costs more gas
    function callExternalViaThis() public view returns (uint) {
        return this.getExternal(); //works but wastes gas
    }  
}

//INHERITANCE AND VISIBILITY

//child cannot inherit and access the private state variables and functions, but internal state variables and functions are accessible

contract Parent{
    uint private secret = 1; // this variable is private to this contract, child cannot access
    uint internal family = 2; // accessible by child
    uint public everyone = 3; // everyone can access

    function _helperInternal() internal pure returns (string memory){
        return "Parent internal";
    }

    function _helperPrivate() private pure returns (string memory){
        return "Parent private";
    }
}

contract Child is Parent{

    //reading internal state varible from parent
    function readFamily() public view returns (uint){
        return family;
    }

    //calling internal function from parent
    function callParentInternal() public pure returns (string memory){
        return _helperInternal();
    }

    //calling private state variables and functions from parent would not compile
    //DOES NOT mean secret on-chain: eth_getStorageAt reads everything
}


//On declaring a public state variable, Solidity automatically generates a getter function with same name

contract AutoGetter{
    uint public balance = 500;
    //Solidity creates: function balance() external view returns (uint256) { return balance; }

    mapping(address => uint256) public scores;
    //Solidity creates; function scores(address key) external view returns (uint256)
    //so call scores(someAddress) from outside with no extra code
}

/**
Security concerns:
- unprotected public mutator (most common bug) : always add require/assert/revert
- private is often mistaken for security:
  it's always readable via eth_getStorageAt, even if hash can't be cracked but the attacker knows the hash and
  can preimage attack offline
- internal virtual fucntions that are security-critical should be carefully reviewed for override risks: consider making the check non-virtual, or using a modifier
- Accidental public on contract-like fucntion in upgradable contract (common in upgradable proxy patterns): use proper constructor as guard
- this.functionName() inside a contract i sexternal call: always note these as potential reentrancy or context shift points as unexpected reentrancy surfaces
- state changing function without access control: investigate immediately
- if the function is part of the contract's public API: use `public` or `external`
  prefer `external` for large arrays, strings or bytes parameters (gas efficient)
*/