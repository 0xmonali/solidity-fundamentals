// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


 /**State Mutability - Regular, View and Pure functions 
   
   Regular Functions
   - Can read and modify both

   View Functions
   - such function do not modify state
   - Can only read state variables
   - Can call other view/pure functions
   - Do not consume gas (when called externally, not form other transactions)
   - Use case: Getters, read-only operations

   Pure Functions
   - No state access at all
   - such functions do not modify and read state variables
   - can only use local variables and function parameters 
   - Do not consume gas (when called externally)
   - Use case: Mathematical calculations, data transformations

   Immutability levels : Regular Function > View Function > Pure Function
 */

contract Functions{

    uint public x = 1;
    uint[] public arr = [10,20,30,40,50];

    /**Multiple return values
     - Functions can return multiple values simultaneously
     - Returns are listed as comma-separated types in the return statements.
     */

    function returnMany() public pure returns (uint, bool, uint){
        return (2, false, 7);
    }

    /**Named Return values
     - Returned values can have explicit names

     Benefits:
     - clear documentation, better readability
     - can be used for implicit returns (next section) 
    */

   function named() public pure returns (uint x, bool b, uint y) {
        return (8, true, 9);
   }

   /**Implicit returns (assigned return values)
    - When return values are named, you can assign to them directly
    - The return statements can be omitted - they're returned automatically 

    Advantages:
    - cleaner code, safer(can't forget to return values)
    - complier automatically returns named variables at the function end

    Note:
    - Only works with named return values 
    */ 

   function assigned() public pure returns (uint x, bool b, uint y){
        x = 5;
        b = false;
        y = 7;
        //implicit return: x, b, y are automatically returned     
   }

   /**Destructing Assignment
    - When a function returns multiple values, you can "destructure" them into separate variables in one assignment
    - Can extract specific values and ignore others using commas
    - Can mix destructing with regular function calls 
    - Can use underscores(_) to skip unwanted return values
    */

   function destructingAssignments() public pure returns(uint, bool, uint, uint, uint){
        //Destructure all there return values from returnMany()
        (uint i, bool b, uint j) = returnMany();
        //i = 2, b = false, j = 7

        //Destructure but skip the middle value (use empty spot)
        (uint x,,uint y) = (4, 5, 6);
        //x = 4, y = 6 (5 is ignored)

        //Return combined results
        return (i, b, j, x, y);
        
        //returns: (2, false, 7, 4, 6)
   }

   /**Array inputs and outputs 
    
    * Array Input:
    - can accept dynamic arrays as input parameters
    - use `memory` keyword for function input (arrays must be in memory)
    - useful for batch opertaions

    * Array Output:
    - Can return arrays from functions
    - Must use `memory` or `storage` keyword
    - `memory` for new arrays
    - `storage` for persistent state arrays

    Security concern: 
    Be cautious with large arrays - high Gas cost
   */

  //Array as input parameters
  function arrayInput(uint[] memory _arr) public pure returns (uint){
    //sum of all elements
    uint sum = 0;
    for (uint i = 0; i<_arr.length; i++){
        sum += _arr[i];
    }

    return sum;
  }

  //Array as output parameters
  function arrayOutput(uint size) public pure returns (uint[] memory){
    uint[] memory newArr = new uint[](size);
    for(uint i = 0; i<size; i++){
        newArr[i] = i*2;
    }
    return newArr; //returning array as output
  }
  

  /**Named function parameters
   
   - Functions can be called with named parameters instead of positional
   - useful when many parameters
   - need to skip optional parameters
   - more resilient to parameter reordering in future upgrades

   syntax: functionName({paraName: value, paraName: value})

   */

  function complexFunction( uint amount, address recipient, bool isUrgent, string memory description, uint timestamp) public pure returns(string memory) {
    return isUrgent ? "URGENT" : "NORMAL";
  } 

  //called with positional arguments (traditional)
  function callWithPositional() public pure returns (string memory){
    return complexFunction(100, address(0), true, "test", 0);
  }

  //called with named arguments(modern, more readable)
  function callWithNamedParameters() public pure returns (string memory){
    return complexFunction({
        amount: 100,
        recipient: address(0),
        isUrgent: true,
        description: "test",
        timestamp: 0 // can't use block.timestamp in pure function
    });
  }

  //Mixed (both postional and named not recommended as it is confusing)

  /**Security concerns:
   * Pure functions with recursion can hit stack limits
   * View functions can be still expensive if state is large
   * Use destructing to extract multiple returns
   * Validate array inputs to prevent gas waste
   * Document the immutability level clearly
   */

}