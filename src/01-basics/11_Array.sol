// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Array{
    //Array - stores multiple values of the same type in order

    //two types of array discussed below
    //DynamicArray -  size changes dynamically (as per use and requirement)
    uint[] public dynamicArr;

    //FixedSizeArray - size is permanently fixed, default values of array is 0
    uint[10] public fixedArr;

    //PreInitialisedArray - Initial values are assigned to the array at the time of the array declaration
    uint[] public preInitialArr = [1,2,3];
    
    function get(uint index) public view returns (uint){
        return preInitialArr[index];
    }

    function getArr() public view returns (uint[] memory){
        //memory- creates a temporary copy of this data while the function is running
        //this memory in RAM gets deleted after the execution of this function
        //this concept is used as direct access to the blockchain - potential threat

        //getArr() function returns the entire array
        //Security concern: array of quite larger length must not return the entire 
        //array using this function - may exhaust the gas

        return preInitialArr;
    }

    function push(uint value) public{
        //push() - used to append(add) the values in array 
        //this value gets appended in the array, increasing the array length by 1
        //security concerns: Storage writes are expensive, each write uses expensive SSTORE
        preInitialArr.push(value);
    }

    function pop() public{
        //pop() is used to remove the last element from the array, decrementing the array length by 1
        //Security concern: cannot pop when array.length is 0, if done so results in failed Transaction 
        preInitialArr.pop();
    }

    function getLength() public view returns (uint){
        //getLength() returns the length of the array (never less than 0, hence uint must always be the return type)
        return preInitialArr.length;
    }

    //security concern: Out of Bounds Access- trying to access an invalid index of the array can revert transactions
    function remove(uint index) public{
        //remove() is used to reset the value of element to its default
        //`delete` is used here to reset the value of the element of that particular index its default, not affecting the arrayLength
        delete preInitialArr[index];

    }
    function memoryArray() public pure returns(uint[] memory){
        //array created in memory
        //cheaper and faster than storage array
        //it exist till execution ofthe function
        uint[] memory a = new uint[](3);

        a[0] = 10;
        a[1] = 20;
        a[2] = 30;

        return a;
    }

    function nestedMemoryArray() public pure returns(uint[][] memory) {

        uint[][] memory b = new uint[][](2);

        b[0] = new uint[](3);
        b[1] = new uint[](3);

        b[0][0] = 1;
        b[0][1] = 2;
        b[0][2] = 3;

        b[1][0] = 4;
        b[1][1] = 5;
        b[1][2] = 6;

        return b;
    }

}

contract RemoveElementAtIndex{
    //this contract is for removing element of an array form the desired index
    //security concern: removing elements at early indexes costs more gas reason - more left shifts of elements
    //also large arrays may cause Out of gas errors (DoS risk)
    
    uint[] public arr;

    function removeAtIndex(uint _index) public{
        //security concern: anyone can call removeAtIndex() since no access control exists
        require(_index < arr.length, "index Out Of Bounds");
        //checks for user input/conditions and revert transaction if false

        for (uint i = _index; i < arr.length - 1; i++){
            arr[i] = arr[i+1];
        }
        arr.pop();
    }

    function check() external{
        //external- function visibility modifier which 
        //makes function callable only from outside the contract
        //to call inside the function, this.function_name() is used, unlike public
        arr = [10,20,30,40,50];
        removeAtIndex(3); //[10,20,30,50]
        assert(arr[0] == 10); //assert - checks internal logic/invariant; failure usually means contract bug
        assert(arr[1] == 20);
        assert(arr[2] == 30);
        assert(arr[3] == 50);
        assert(arr.length == 4);
        
    }
}