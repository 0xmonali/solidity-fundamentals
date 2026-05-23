// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Loop{
    // safer to use - bounded loops, pagination ,batch processing
    function loop() public pure{
        // for loop 
        // for loops are safer than while loops but still dangerous if bound depends on array length
        // e.g. for(uint i = 0; i < users.length; i++) - attacker can add users to cause DoS
        for (uint i = 0; i < 10; i++){
            //after every iteration i increments by 1

            //condition checking when i is equal to 4
            if (i == 4){
                continue; //skips the rest instructions inside the for loop on encountering i is equal to 4
            }

            if(i == 7){
                break; //for loop execution stops when i is equal to 7
            }
        }


        // while loop (avoid unbounded loops)
        uint x; // set to default = 0
        // while the condition inside the parentheses is true
        // the loop executes the block of instructions written inside it 
        while (x < 10){
            x++; // on every iteration of loop x increments by 1
        }
        // while loops are dangerous in solidity because of unbounded iterations
        // can consume excessive gas, causing transaction failure or 
        // DoS vulnerabilities
    }
}