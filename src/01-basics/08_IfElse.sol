// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// IfElse - conditional logic in Solidity, works as same as if/else in other languages
// ternary operator is also supported

contract IfElse {

    // sample threshold value for demonstrating conditions
    uint public constant THRESHOLD = 10000 gwei;

    // standard if / else if / else
    // returns 0 if x < THRESHOLD, 1 if equal, 2 if greater
    // Security: be careful with == comparisons on uint - off by one errors are common and hard to spot in audits
    function condition(uint x) public pure returns (uint) {
        if (x < THRESHOLD) {
            return 0;
        } else if (x == THRESHOLD) {
            return 1;
        } else {
            return 2;
        }
    }

    // ternary operator - shorthand for simple if/else
    // syntax: condition ? valueIfTrue : valueIfFalse
    // slightly cheaper gas than full if/else for simple cases
    // use only for simple single-line returns - complex ternaries are hard to read and audit
    // auditors usually flag complex ternary as they are hard to verify
    
    function ternaryOp(uint _x) public pure returns (uint) {
        return _x < THRESHOLD ? 0 : 2;
    }
}