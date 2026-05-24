// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

//user defined value type (UDVT) - introduced in Solidity 0.8.8
//custom type created by developers using an existing primitive Solidity type to provide 
//- better type safety, clearer code readability, prevention of accidential misuse

//syntax: type <TypeName> is <primitiveType>

type Age is uint256;
type Weight is uint256;

contract UDVT{

    //without UDVT- both are uint256, easy to mix up
    function noUDVT(uint256 age, uint256 weight) public pure returns(uint256){
        return age + weight;
    }
    
    //withUDVT - compiler is able to catch the wrong input order at compile time
    function withUDVT(Age age, Weight weight) public pure returns (uint256){
        
        //TypeName.unwrap - unwraps the UDVT into primitive dataType
        return Age.unwrap(age) + Weight.unwrap(weight);
    }

    function example() public pure{
        
        //TypeName.wrap -  wraps the primitive dataType into UDVT
        Age myAge = Age.wrap(21);
        Weight myWeight = Weight.wrap(70);

        withUDVT(myAge, myWeight); //correct 
        
        //Common error made is: withUDVT(myWeight, myAge) - this would not compile due to type safety enforced by compiler
        //wrong order of parameters in withUDVT function
    }
    /*Security concerns: 
    1. UDVT DO NOT validate data - the data provided or assigned to this dataType can be invalid
       (best practice- use require() to validate data)
    2. Unsafe unwrap() usage - Type safety disappears and becom normal primitive type
       (best practice - always audit all the unwrap() usage)
    3. Inside assembly, Type safety disappears completely
       (best practice - Minimise assembly usage)*/

}