// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
Events:

Events are solidity's logging system
- log entry is written permanently to blockchain but not stored in contract storage
- contract storge: expensive, lives inside contract, readable by other contracts
- Event logs: cheap, lives in transaction receipt, not readable by contract

Without events: function runs -> state changes -> complete silence
- frontend has no info what happened
- security tools see nothing
- no history created

With Events: function runs -> state changes -> Log written permanently
- frontend updates instantly
- security tools see everything
- history on-chian forever

What is log?
- actual data written on-chain on emitting an event

Event = template ; log = actual entry written

Syntax:

event event_name(datatype var1, datatype var2);
emit event_name(value1, value2);

 */


contract Events1{

    mapping(address => uint) public balances;

    event Deposited(address who, uint amount);
    event Withdrawn(address who, uint amount);

    function deposit() external payable{
        require(msg.value > 0, "Zero");
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value); //write log
    }

    function withdraw(uint amount) external{
        require(balances[msg.sender] >= amount, "Insufficient");
        balances[msg.sender] -= amount;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "Failed");
        emit Withdrawn(msg.sender, amount); //write log
    }

}


/**
Indexed keyword
-indexed makes the field searchable- like adding a search filter

Without indexed:
- must scan every single transaction ever
- slow, impractical

With indexed::
- direct filter on topic
- instant result

Rules:
- max 3 indexed params per event 
- indexed = slightly more gas but searchable
- non-indexed = cheaper, still readable, just not filterable

Every log has 2 sections: Topic and Data

Topic (indexed - searchable, 32- bytes each)

- topic[0] = event signature automatic (keccak256 hash - never seen manually)
- topic[1] = 1st indexed param
- topic[2] = 2nd indexed param
- topic[3] = 3rd indexed param

-max 4 topics are allowed

Data (non-indexed - ABI encoded blob)

- all non-indexed params packed together here readable but not filterable


Log opcodes (EVM level)

what actually happens when you emit?
The EVM has 5 log opcodes, solidity picks the right one based on the number of indexed params

LOG0 -> no indexed param -> only data
LOG1 -> 1 indexed param -> topic[0] + data
LOG2 -> 2 indexed param -> topic[0,1] + data
LOG3 -> 3 indexed param -> topic[0,1,2] + data
LOG4 -> 4 indexed param -> topic[0,1,2,3] + data

example:

event Transfer(address indexed from,  
                     address indexed to, 
                     uint amount
                    );

emit Transfer(sender, receiver, 527);

compiles down to LOG3:

LOG3(
    dataoffset, //where 500 sits in memory
    dataLength, // how many bytes the data is 
    keccak256("Transfer(address, address, uint256)"), //topic[0] 
    sender, //topic[1]
    receiver) //topic[2]

- 500 goes to the DATA, not topics

Gas cost of logs:

- base cost per log : 375 gas
- per topic : 375 gas each
- per byte of data : 8 gas

so Transfer(indexed, indexed, uint256):
375 (base)
+ 375 (topic[0] signature)
+ 375 (topic[1] from)
+ 375 (topic[2] to)
+ 256 (32 bytes of data x 8)
= ~1756 gas total

compare to SSTORE (storage write) = 20000+ gas
Events are ~10x cheaper than storage


Dynamic types lose their value when indexed: 
- because only hash stored and original value lost forever

*/



contract IndexedNonIndexed {

    //nothing indexed - can't filter by anything, but readable
    event NonIndexedLog(address from, address to, uint amount);
   
    // from and to are searchable, amount is readable
    event IndexedLog(address indexed from,  
                     address indexed to, 
                     uint amount
                    );

    function transfer(address to, uint amount) public {

        //no filter possible
        emit NonIndexedLog(msg.sender, to, amount);

        //can filter all transfers FROM me or all transfers TO me
        emit IndexedLog(msg.sender, to , amount);
    }
    
}

/**
Security concerns:

- Missing event on ownership transfer - silent takeover, monitor tools blind
- Missing event on fee change: owner silently raises fees from 1% to 99%
- Missing event on pause: contract paused silently, users have no warning
- Event emitted before state finalized: log says success but transaction later fails
- Wrong values in event: dashboard shows incorrect amounts, TVL trackers corrupted
- Indexing a string or bytes: stores hash not actual value, original data lost forever
- No events at all: entire protocol history invisible, unauditable off-chain 
- Relying on events inside contract: contacts cannot read their own logs, logic breaks
 */


