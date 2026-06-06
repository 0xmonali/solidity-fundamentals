// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/*
Transient storage

-Temparary storage data exists only during the current transaction
-Data utomatically cleared when the transaction ends
-Saves gas compared to regular storage
*/

contract TransientStorage {
    
    mapping (address => uint) public balances; //regular storage

    bool transient locked; //transient storage
    uint transient txFeeTotal;
    //Security concern: txFeeTotal is transient(reset after every transaction),
    //It should not be used for persistent fee accounting 

    function deposit() external payable{

        //Security concern: No input validation for zero deposits
        // - Could add: require(msg.value > 0, "Deposit must be > 0");
        balances[msg.sender] += msg.value;

        //Recommended: Emit a deposit event for easier off-chain tarcking
    }

    function withdraw(uint amount) external{

        //Reentrancy guard using transient storage (gas-optimal)
        require(!locked, "No reentrant calls");
        locked = true;

        //Security concern: No validation for zero amount 
        //Could add: require(amount > 0, "Amount must be > 0");
        require(balances[msg.sender] >= amount, "Insuffient balance"); //Checks

        //Update state before extrenal call, CEI (Checks-Effects-Interactions) pattern
        balances[msg.sender] -= amount; //Effects
        txFeeTotal += amount/100;


        //Security Concern: using .call() over .tranfer() is better
        (bool ok, ) = msg.sender.call{value: amount - amount/100}(""); //Interactions   
        require(ok, "Transaction failed");

        locked = false; 
        //Recommended: Emit a withdraw event

    }

    function getTransactionFees() external view returns (uint){
        return txFeeTotal;
    }

    /**Future Modifications to be made:
     * Add event emissions for Deposit and Withdraw
     * Implement persistent fee tarcking with admin withdrawal function
     * Add Owner-based access control 
     */
}