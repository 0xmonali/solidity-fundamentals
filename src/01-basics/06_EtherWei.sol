// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

//Ether is the native currency of Ethereum used to:
//Pay gas fees, send value between the accounts, store/send money inside smart contracts
                                                     
// Solidity has built-in unit keywords for ether
// wei - smallest unit of Ethereum money 
// 1 gwei  = 1e9 wei  = 10^9 wei = 1,000,000,000 wei (mostly used for gas)
// 1 ether = 1e18 wei = 10^18 wei = 1,000,000,000,000,000,000 wei
// Similar to $1 = 100 cents

contract EtherUnits {

    // wei - smallest unit, base unit of all ETH math in EVM
    // every ETH value in Solidity is actually stored and calculated in wei
    uint256 public oneWei = 1 wei;
    bool public isOneWei = (oneWei == 1); // true, when 1 wei == 1

    // gwei - used for gas prices (X gwei per gas unit)
    uint256 public oneGwei = 1 gwei;
    bool public isOneGwei = (oneGwei == 1e9); // true

    // ether - the unit we humans think in, but EVM always uses wei inside the blockchain
    // 1 ether = 10^18 wei
    uint256 public oneEther = 1 ether;
    bool public isOneEther = (oneEther == 1e18); // true

    // Common bug: sending msg.value == 1 checks for 1 WEI not 1 ETHER
    // correct check: require(msg.value == 1 ether)
    // wrong check:   require(msg.value == 1) -- only accepts 0.000000000000000001 ETH
}