// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

//Struct is a custom datatype used to group similar variables together
//syntax: struct <StructName> {<variables>}

contract Struct {

    //basic struct
    struct Person {
        string name;
        uint age;
        address wallet;
    }

    //nested struct
    //A struct containing another struct as a field

    struct Company {
        string name;
        Person ceo; //nested struct
        uint founded;
    }

    //storage
    Person[] public people;
    Company[] public companies;

    /* Initialization:
    
    for positional initialization-
    StructName memory variableName = StructName(value1, value2);

    for key-value initialization-
    StructName memory variableName = StructName({
        variable1: value1,
        variable2: value2
    });


    using `memory` here - to create a temporary student object while the function is running 
    then after that when we use .push() in struct, then that temporary student is permanently 
    saved on blockchain


    why not using `storage`?

    Storage is for data that already exists on blockchain.
    Then, if we use - StructName storage variableName = StructName(value1, value2)
    tries to create a new struct and make it a storage reference,
    Solidity does not allow that.
    storage only points to existing blockchain data, like a pointer/reference
    
    */


    //this function below is assigning the values of the variables of struct Person
    function initializationPerson(string memory _name, uint _age)  public {

        //method -1 
        //positional initialization
        Person memory p1 = Person(_name, _age, msg.sender);

        //method -2
        //key-value initialization (recommended - safer, order independent)
        Person memory p2 = Person(
            {
                name: _name,
                age: _age,
                wallet: msg.sender
            }
        );

        people.push(p2); //use of push in struct is similar to that of in array
    }

    function initializationCompany(string memory _name, Person memory _ceo, uint _founded) public {
        //method-1
        //positional initialization
        Company memory c1 = Company(_name, _ceo ,_founded);

        //method-2 
        //key-value initialization (recommanded)
        Company memory c2 = Company({
            name: _name,
            ceo: _ceo,
            founded: _founded
        });

        companies.push(c2);
    }

    function update(uint _index, uint _newAge)  public{
        //
        people[_index].age = _newAge;
    }

    function remove (uint _index) public{
        delete people[_index];
    }

   // security concerns:
   // no index bound check in update/delete can revert
   //memory or storage - common = confusion

}