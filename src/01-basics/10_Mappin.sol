// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/*
Mapping - a hash table-based key-value data structure 
    that stores and retrives values using unique keys with constant-time lookup 
    complexity 
    
    Syntax - mapping(keyType => valueType)
    
    where, keyType - any valid build-in dataType or any contract
           valueType - any valid dataType or any other mapping or an array
           
    Mappings are non-Iterable
*/

contract Mapping{
    //mapping from uint to address, named ownerOf
    mapping(uint => address) public ownerOf; 

    //mapping always returns a value 
    //When no value is set, it returns a default value
    //security concern: would never distinguish whether the value was never set 
    //or was deleted or was assigned with default value itself 

    function get(uint _tokenId) public view returns (address){ 
        //This function returns the address corresponding to the tokenId
        return ownerOf[_tokenId];
    }  

    function set(uint _tokenId, address _addr) public{
        //This function sets the tokenId with address associated with it

        //Security: _addr could be address(0) - no validation here
        //in real NFT contracts always check:
        //require(_addr != address(0))
        ownerOf[_tokenId] = _addr;
    }

    function remove(uint _tokenId) public{
        //This function uses `delete` to reset the value of the keyType to its default
        //common mistake - sometimes `delete` is misunderstood as it will delete the key-value pair from the mapping
        //but it's NEVER like that
        delete ownerOf[_tokenId];
    } 

    //Security concern:
    //can't really check whether the key ever exixted or not or deleted(burned) eariler, as it shows the default value in both the cases
    //Unbounded growth of mapping - gas exhaustion is the result (solved by maintaining a separate array )
}


contract NestedMapping{
    //Nested mapping - A mapping where key is mapped with another mapping
    mapping(address => mapping(address => uint)) public allowanceNested;

    function get(address _owner, address _spender) public view returns (uint){ 
        return allowanceNested[_owner][_spender];
    }  

    function set(address _owner, address _spender, uint _allowance) public{
        allowanceNested[_owner][_spender] = _allowance;
    }

    function remove(address _owner, address _spender) public{
        delete allowanceNested[_owner][_spender];
    } 

    //Security concern: Nested mapping deletion
    //deleting outer key never delete the inner data
    //e.g. allowanceNested[_owner] is impossible
    //inner memory stays in the storage forever

    //mapping are NOT private even if marked private, 
    //anyone can read storage slots directly on-chain
}