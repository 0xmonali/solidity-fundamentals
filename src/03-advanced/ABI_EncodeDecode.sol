// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
ABI ENCODING DECODING 

Everytime on calling a fucntion on Ethereum, arguments get serialized into bytes before 
hitting the EVM. The EVM has no concept of "string" or "uint256" natively - everything is 
bytes. ABI encoding is the rulbook for how Solidity type map to those bytes

This matters for:
- function calls between contracts (.call(), interfaces)
- passing data as bytes in low-level calls
- hashing and emitting events off-chain
- building call manually (used in proxy patterns, multicall, etc.)
*/

// ABI.ENCODE VS ABI.ENCODEPACKED

/**
abi.encode(arg1, arg2, ...)

- pads EVERY argument to 32 bytes regardless of its actual size
- each value has a fixed, known boundary in the output
- output length is always a multiple of 32 bytes
- safe to hash multiple values together (no ambiguity)
- more gas than encodePacked due to padding 

abi.encodePacked(arg1, arg2, ...)

- packs arguments tightly with NO padding
- each type only takes as many bytes as it actually needs:
    uint256 -> 32 bytes (fixed-width type, no difference)
    uint8 -> 1 byte
    address -> 20 bytes
    bool -> 1 byte
    string -> raw bytes only, no length prefix, no padding
    bytes -> raw bytes only

- smaller output = cheaper to hash
- BUT: ambiguous boundaries when multiple dynamic values (hash collision risk)

When to use which:
    abi.encode -> hashing multiple values, calldata building, cross-contract data
    abi.encodePacked -> single value hashing, gas-sensitive leaf nodes in merkle trees
                        (only safe when NO two adjacent dynamic types exist)
*/

contract EncodeDecodeBasics {
    event EncodeOutput(bytes data);

    /**
    encode() output breakdown for (uint256(123), address(0xABCD), true, "hello"):

    bytes 0-31 : uint256(123) padded to 32 bytes
    bytes 32-63 : address padded to 32 bytes (left-padded with zeros)
    bytes 64-95 : bool(true) padded to 32 bytes
    bytes 96-127 : offset pointer to string data (dynamic type)
    bytes 128-159 : string length (5 for "hello")
    bytes 160-191 : string data "hello" right-padded to 32 bytes

    total: 192 bytes 
    */

    function encodeExample() external pure returns (bytes memory){
        return abi.encode(uint256(123), address(0xABCD), true, "hello");
    }

    /**
    encodePacked() output breakdown for same input:

    bytes 0-31 : uint256(123) - fixed type, still 32 bytes
    butes 32-51 : address - 20 bytes only, no padding
    bytes 52 : bool(true) - 1 byte only
    bytes 53-57 : "hello" - 5 bytes only, no length, no padding

    total: 58 bytes vs 192 bytes above
    */

   function encodePackedExample() external pure returns (bytes memory) {
    return abi.encodePacked(uint256(123),address(0xABCD),true,"hello");
   }

   /**
    HASH COLLISION - the core danger o fencodePacked with dynamic types

    Because encodePacked strips boundaries between values, different input combination can identical byte sequences.

    abi.encodePacked("hello", "world") -> bytes: 68656c6c6f776f726c64
    abi.encodePacked("hell", "oworld") -> bytes: 68656c6c6f776f726c64
    abi.encodePacked("hellow", "orld") -> bytes: 68656c6c6f776f726c64

    All three are identical. keccak256 of identical bytes = identical hash

    Security concern:
    If a contract uses keccak256(abi.encodePacked(str1, str2)) to verify user-supplied data, an attacker submits a different 
    (str1, str2) pair that produces the same bytes -> passes verification without knowing the original.

    This breaks commit - reveal schemes, whitelist checks, and signature verification

    */

   function hashCollision() external pure returns (bytes32 hashA, bytes32 hashB, bool collides) {
    hashA = keccak256(abi.encodePacked("hello","world"));
    hashB = keccak256(abi.encodePacked("hell","oworld"));
    collides = (hashA == hashB); //true - same hash, different inputs
   }

   function hashNoCollision() external pure returns(bytes32 hashA, bytes32 hashB, bool collides) {
    hashA = keccak256(abi.encode("hello","world"));
    hashB = keccak256(abi.encode("hell","oworld"));
    collides = (hashA == hashB); //false - padding preserves boundaries
   }

}

/**
ABI DECODE

- exact reverse of abi.encode
- must know the types and their order at decode time
- will revert if:
    - data is too short for the declared types
    - data is malformed (e.g. string length exceeds remaining bytes)
- will silently return garbage if you decode the wrong types
  (no revert, just wrong values - dangerous)

Security concerns:
- decoding bytes from an untrusted external source without length checks can cause unexpected reverts, griefing control flow
- decoding wrong types produces garbage silently - always verify the source
- if success=true from .call() but data is empty, abi.decode reverts always check data.length > 0 before decoding call return data
*/

contract DecodeExample {
    event Decoded(uint256 num, address addr, bool flag, string text);
    event ResultDecoded(uint256 result);

    //basic roundtrip: encode then decode
    function encodeAndDecode() external pure returns (uint256 num, address addr, bool flag, string memory text) {
        bytes memory encoded = abi.encode(uint256(42), address(0x1234), true, "monali");

        //types must match encoding ordeer exactly 
        //wrong order = garbagevalues, no revert
        (num, addr, flag, text) = abi.decode(encoded, (uint256,address,bool,string));
    }

    /**
    DECODING .CALL() RETURN DATA

    .call() returns (bool success, bytes memory data)
    data contains the ABI-encoded return value of the called function.
    Need to know what the function returns to decode it correctly.
    */
    function decodeCallReturn(address _target) external payable{
        (bool success, bytes memory data) = _target.call{value: msg.value}(abi.encodeWithSignature("foo(string,uint256)", "test", 99));
        require(success, "call failed");

        //Security concern:
        //success = true with empty is valid
        //(function returned nothing) - abi.decode on empty bytes reverts
        require(data.length >= 32, "no return data");

        uint256 result = abi.decode(data, (uint256));
        emit ResultDecoded(result);
    }

    /**
    SAFE DECODE PATTERN

    abi.decode inside try/catch doesn't work directly.
    Common safe pattern: check length, then decode.
    For untrusted data, wrap teh decode call in an external function and try/catch on that
    
    */
    function safeDecode(bytes memory data) external pure returns (bool ok, uint256 result){

        //minimum 32 bytes needed to decode a single uint256
        if (data.length < 32) {
            return (false,0);
        }

        result = abi.decode(data, (uint256));
        return (true, result);
    }

    //wrong type decode - compile fine, returns garbage silently 
    //Security concern: this is how incorrect decoding looks - no error

    function wrongTypeDecode(bytes memory data) external pure returns (address garbage){
        
        //data was encoded as uint256 but decoded as address
        //no revert, just wrong value - this is the silent danger
        (garbage) = abi.decode(data, (address));
    }
}

/**
ENCODING STRUCTS AND ARRAYS

structs encode as tuples - each field encoded in declaration order.
arrays encode with a length prefix followed by each element

Security concern (ABI encoding vs EVM storage layout are DIFFERENT):

EVM storage: packs samll types together into 32-byte slots
    struct {uint128 a; uint128 b; } -> both fit in one storage slot

ABI encoding: always 32 bytes per element
    abi.encode(uint128, uint128) -> 64 bytes (each padded to 32)

Don't confuse them when:
- calculating expected byte offsets in calldata
- decoding storage values manually using assembly
- reasoning about proxy storage layout (storage = slots, not ABI)

*/

contract StructAndArrayEncoding{
    struct User {
        address wallet; //20 bytes in storage, 32 bytes in abi
        uint256 balance; //32 bytes in both
        string name; //dynamic, 32-byte length prefix + data in ABI
    }

    //encoding a struct - two equivalentg ways
    function encodeUserExplicit(User memory user) external pure returns (bytes memory){
        return abi.encode(user.wallet, user.balance, user.name); //explicit - field by field
    }

    function encodeUserDirect(User memory user) external pure returns (bytes memory){
        return abi.encode(user); //Solidity supports encoding struct directly, same output
    }

    //decoding struct fields
    function decodeUser(bytes memory data) external pure returns (address wallet, uint256 balance, string memory name) {
        (wallet, balance, name) = abi.decode(data, (address, uint256, string));
    }

    //encoding a dynamic array
    function encodeArray(uint256[] memory arr) external pure returns (bytes memory){
        //output: 32-byte length + 32bytes per element
        return abi.encode(arr);
    }

    //decoding a dynamic array
    function decodeArray(bytes memory data) external pure returns (uint256[] memory){
        return abi.decode(data, (uint256[]));
    }

    //encoding a nested struct array - common in protocol data
    function encodeUserArray(User[] memory users) external pure returns (bytes memory) {
        return abi.encode(users);
    }

}

/**
KECCAK256 + ABI.ENCODE - ON-CHAIN HASHING

keccak256(abi.encode(...)) is teh standard pattern for:
- commit-reveal schemes (hide a value, reveal later)
- merkle tree leaf construction
- on-chain storage of commitments
- generating unique IDs from structured data

RULE: use abi.encode not encodePacked when hashing multiple values
      unless you are absolutely certain no two adjacent dynamic types exist.

*/

contract CommitReveal {
    mapping(address => bytes32) public commitments;
    mapping(address => bool) public revealed;

    event Committed(address indexed user, bytes32 hash);
    event Revealed(address indexed user, uint256 value, string salt);

    /**
    COMMIT PHASE
    User computes off-chain: keccak256(abi.encode(secretValue, salt)) and submits only the hash.
    Value stays hidden until reveal.

    Security concern:
    - if the value space is small (e.g. a coin flip: 0 or 1), an attacker can precompute both hashes and frontrun the reveal
    - always include a user-specific salt to prevent this
    - salt should be long and random, not predictable
    
    */
   function commit(bytes32 _hash) external {
    require(commitments[msg.sender] == bytes32(0), "already committed");
    commitments[msg.sender] = _hash;
    emit Committed(msg.sender, _hash);
   }

   /**
   REVEAL PHASE
   User submites the original values and salt
   Contarct recomputes the hash and verifies

   Security concern:
    - encoding mismatch between commit (off-chain) and reveal(on-chain) is a common bug: off-chain uses encodePacked, on-chain 
     uses encode, reveals always fails, funds locked
    -always document which encoding is used and test both sides
    */
    function reveal(uint256 _value, string calldata _salt) external returns (bool valid) {
        require(commitments[msg.sender] != bytes32(0), "no commitment");
        require(!revealed[msg.sender], "already revealed");

        bytes32 hash = keccak256(abi.encode(_value, _salt));
        valid = (hash == commitments[msg.sender]);

        if (valid) {
            revealed[msg.sender] = true;
            emit Revealed(msg.sender, _value, _salt);
        }
    }

    //vulnerable version - encodePacked with two dynamic types
    function revealVulnerable( string calldata _part1, string calldata _part2) external view returns (bool) {
        //security concern: hash collision possible
        //("hello","world") and ("hell", "oworld") pass the same commitment
        bytes32 hash = keccak256(abi.encodePacked(_part1, _part2));
        return hash == commitments[msg.sender];
    }

}

//EIP-712 STRUCTURED DATA HASHING

/**
EIP-712: Typed Structed Data Hashing for signing

PROBLEM with naive keccak256(abi.encode(data)) for signatures:
1. repaly attacks: same signature works on different chains or contracts
2. blind signing: MetaMask shows raw bytes, user can't read what they signed
3. no nonce: same signature can be submitted multiple times

EIP-712 SOLUTION:

Step-1: DOMAIN SEPARATOR (binds signature to this specific contract + chain):
        keccak256(abi.encode(
            TYPE_HASH_OF_DOMAIN, //describes the domain struct
            keccak256(name), //protocol name
            keccak256(version), //protocol version 
            block.chainid, //protocol cross-chain replay
            address(this) //prevents cross-contract replay
            ))

Step-2: STRUCT HASH (encodes the actual data being signed):
        keccak256(abi.encode(
            TYPEHASH, //keccak256 of the struct type string
            field1,
            field2,
            ...
            ))

Step-3: FINAL DIGEST (what the user actually signs):
        keccak256(abi.encodePacked(
            "\x19\x01", //EIP-712 magic prefix - prevents collisions with raw tx hashes
            domainSeparator, //bytes32 - fixed size
            structHash //bytes32 - fixed size
            ))

NOTE: encodePacked is SAFE in step 3 because both inputs are fixed bytes32.
      NO dynamic types = no collision risk

Security concern for EIP-712:

- missing chainID -> signature replayed on different chain (mainnet vs testnet)
- missing verifyingContract -> signature replayed on different contract
- missing nonce -> smae signature submitted multiple times
- wrong type string in TYPEHASH -> signatures always fail (typo = different hash)
- hashing string/bytes fields: must be keccak256(field), not the raw value
  e.g. struct with string name -> TYPEHASH field is keccak256(name)
- off-chain signer and on-chain verifier must use IDENTICAL struct field order
- ecrecover returns address(0) on invalid signature - always check for this

*/

contract EIP712 {
    
    //domain
    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 private constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name, string version, uint256 chainId, address verifyingContract)");

    //struct

    //type string: no spaces, canonical types, field names included
    //Security concern: spaces or wrong types here = wrong TYPEHASH = all sigs fail
    bytes32 public constant TRANSFER_TYPEHASH = keccak256("Transfer(address from, address to, uint256 amount, uint256 nonce)");

    //state
    mapping(address => uint256) public nonces;
    mapping(address => uint256) public balances;

    event TransferExecuted(address indexed from, address indexed to, uint256 amount);

    constructor() {
        //domain separator computed once at deploy
        //immutable = cheaper to read than storage (no SLOAD, uses CODECOPY)
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            DOMAIN_TYPEHASH,
            keccak256("MyProtocol"), //name
            keccak256("1"), //version
            block.chainid, //chain binding
            address(this) //contract binding
        ));
    }

    //hashing helpers

    function getStructHash(address from, address to, uint256 amount, uint256 nonce) public pure returns (bytes32) {
        return keccak256(abi.encode(TRANSFER_TYPEHASH, from, to, amount, nonce));
    }

    function getDigest(bytes32 structHash) public view returns (bytes32) {
        //encodePacked safe: \x19\x01 + bytes32 + bytes32 = all fixed size
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }

    //SIGNATURE VERIFICATION

    /**
    executeTransfer:
    - `from` signs the transfer off-chain using their private key
    - anyone can submit the signature on-chain (gasless for the signer)
    - contract verifies the signature matches the expected digest
    - nonce prevents replay of the same signature

    This is the foundation of meta-transactions and permit() (EIP-2612)
    */

    function executeTransfer(address from, address to, uint256 amount, uint8 v, bytes32 r, bytes32 s) external {
        //checks
        require(balances[from] >= amount, "insufficient balance");

        //nonce: consume before verification to prevent replay
        //Security concern: nonce must increment BEFORE ecrecover check
        //incrementing after = TOCTOU window for replay
        uint256 nonce = nonces[from]++;
        
        //build teh digest the signer should have signed
        bytes32 structHash = getStructHash(from, to, amount, nonce);
        bytes32 digest = getDigest(structHash);

        //ecrecover: recovers the address that produced this (v,r,s) for this digest
        address signer = ecrecover(digest, v, r, s);

        //Security concern: ecrecover returns address(0) for invalid signatures
        //without this check, address(0) could be treated as a valid signer
        require(signer != address(0), "invalid signature");
        require(signer == from, "signer is not sender");

        //effects
        balances[from] -= amount;
        balances[to] += amount;

        emit TransferExecuted(from, to, amount);
    }

    //helper: verify without executing

    function verifySignature(address from, address to, uint256 amount, uint256 nonce, uint8 v, bytes32 r, bytes32 s) external view returns (bool valid, address recoveredSigner) {
        bytes32 structHash = getStructHash(from, to, amount, nonce);
        bytes32 digest = getDigest(structHash);
        recoveredSigner = ecrecover(digest, v, r, s);
        valid = (recoveredSigner != address(0) && recoveredSigner == from);
    }

    //deposit for demo purposes
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }
}




