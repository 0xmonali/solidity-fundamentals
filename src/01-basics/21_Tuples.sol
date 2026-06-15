// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/**
Tuple:
- a fixed-sized, ordered group of values of different types bundled together
 */

contract Tuple{

    struct Position{
        uint256 collateral;
        uint256 debt;
        bool isActive;
    }

    mapping (address => Position) public positions;

    //getPosition() returns a tuple of 3 values
    function getPosition(address user) public view returns (uint256 collateral, uint256 debt, bool isActive){
        Position storage p = positions[user];
        return (p.collateral, p.debt, p.isActive); 
    }

    //destructuring tuple
    function getHealthFactor(address user) external view returns (uint256){
        (uint256 col, uint256 debt, bool active) = getPosition(user);

        if (!active || debt == 0) return type(uint).max;
        return (col*1e18)/debt;
    }


    //security concern: skipping wrong slot
    function badOracleRead (address oracleAddr) external view returns (int256){
        //imagine oracle returns (rundId, price, timestamp)
        //skipping wromg slot - reading timestamp as price
        (,,uint256 price) = IFakeOracle(oracleAddr).getData();
        return int256(price); // actually returns the timestamp
    }

    function goodOracleRead(address oracleAddr) external view returns (int256){
        (,int price, uint256 timestamp) = IFakeOracle(oracleAddr).getData();
        require(price > 0, "Invalid price");
        require(timestamp >= block.timestamp - 1 hours, "Stale");
        return price;
    }

    //Security concern : abi.decode wrong order
    function badDecode(bytes calldata data) external pure returns (address, uint256){
        //if data was encoded as (uint256, address) this is corrupted
        (address a, uint256 b) = abi.decode(data, (address, uint256));
        return (a,b);
    }

    //order must match how it was encoded
    function goodDecode(bytes calldata data) external pure returns (uint256, address){
        //if data was encoded as (uint256, address) this is corrupted
        (uint256 a, address b) = abi.decode(data, (uint256, address));
        return (a,b);
    }

    //Security concern: unchecked .call() return tuple
    function badTransfer(address to, uint256 amount) external {
        (bool ok, ) = payable(to).call{value: amount} ("");
        // `ok` never checked, silently loss 
    }

    function goodTransfer(address to, uint256 amount) external{
        (bool ok, bytes memory err) = payable(to).call{value: amount}("");
        require(ok, string(err));
    }
}

interface IFakeOracle {
    function getData() external view returns (uint256, int256, uint256);
}

/**Security checklist:
 
 * Destructuring order matches return signature exactly?
 * Skipped slots (,) are actually the right ones to skip?
 * All returned values validated after destructuring?
 * .call() bool slot always checked after destructuring?
 * abi.decode type tuple matches abi.encode order?
 * External oracle tuples - staleness + validity checked?
 * Chainlink - all 5 slots of latestRoundData validated?
 * Upgrade changed return tuple shape - callers updated?
 * try/catch tuple return values validated?
 * No implicit type casting between tuple slots?
 */