// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
Constructor:

A special function that runs only once and thats during deployment
after that never runs again

After deployment- the constructor code is erased from the bytecode

*/

contract Ownable{
    address public owner;

    constructor(address _owner){
        require(_owner != address(0), "Zero address owner");//zero address is 0x0000...0000, i.e., null address
        owner = _owner; //sets ownership to deployment
    }

    modifier onlyOwner(){
        require(msg.sender == owner, "Not Owner");
        _;
    }

}


//inherits Ownable

contract MyApp is Ownable{
    uint public fee;
    string public appName;

    constructor(address _owner, string memory _appName) Ownable(_owner) {
        require(bytes(_appName).length > 0, "Empty name");
        appName = _appName;
        fee = 100;
    }

    //only owner can change the fee
    function setFee(uint _fee)  external onlyOwner {
        require(_fee <= 1000, "Fee too high");
        fee = _fee;
    }

    //only owner can change name
    function setAppName(string memory _name) external onlyOwner{
        require(bytes(_name).length > 0, "Empty name");
        appName = _name;
    }

    //anyone can read
    function getDetails() external view returns (address, string memory, uint) {
        return (owner, appName, fee);
    }

/**
Security concerns:
- Owner set to msg.sender instead of parameter as then owner is set to factory instead of real user 
- Missing zero address check
- Every constructor parameter needs a sanity check (validation on parameters)
- Constructor arguments are public on-chain
- Always explicitly call parent constructor
- wrong constructor chaining order. e.g., constructor() b() a() {} - this calls b first then a
  always chain the constructor in the same order as inheritance declaration
- Initializable proxy pattern - must use OpenZeppelin's initializer modifier: prevents calling twice
- state set after constructor can override constructor values: inline state declarations run before constructor body, order matters 
- assert in constructor burns deployer gas, require refunds the gas (always use require in constructor)

 */
}