// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract MultiSig {
    
    address[] public signers;
    uint256 quorum;
    uint256 txCount;

    address owner;
    address nextOwner;

    struct Transaction {
        uint256 id;
        uint256 amount;
        address receiver;
        uint256 signersCount;
        bool isExecuted;
        address txCreator;
    }

    Transaction[] allTransactions;

    mapping(uint256 => mapping(address => bool)) hasSigned;

    mapping(uint256 => Transaction) transactions;

    mapping(address => bool) isValidSigner;

    constructor(address[] memory _validSigners, uint256 _quorum) payable  {
        owner = msg.sender;
        signers = _validSigners;
        quorum = _quorum;

        for (uint8 i = 0; i < _validSigners.length; i++) {
            require(_validSigners[i] != address(0), "get out");

            isValidSigner[_validSigners[i]] = true;
        }
    }

    function initiateTransaction(uint256 _amount, address _receiver) external {
        require(msg.sender != address(0), "zero address detected");
        require(_amount > 0, "no zero value allowed");

        onlyValidSigner();

        uint256 _txId = txCount + 1;

        Transaction storage tns = transactions[_txId];

        tns.id = _txId;
        tns.amount = _amount;
        tns.receiver = _receiver;
        tns.signersCount = tns.signersCount + 1;
        tns.txCreator = msg.sender;

        allTransactions.push(tns);

        hasSigned[_txId][msg.sender] = true;

        txCount = txCount + 1;
    }

    function approveTransaction(uint256 _txId) external {
        require(_txId <= txCount, "invalid transaction id");
        require(msg.sender != address(0), "zero address detected");

        onlyValidSigner();

        require(!hasSigned[_txId][msg.sender], "can't sign twice");
        Transaction storage tns = transactions[_txId];
        require(
            address(this).balance >= tns.amount,
            "insufficient contract balance"
        );

        require(!tns.isExecuted, "transaction already executed");
        require(tns.signersCount < quorum, "quorum count reached");

        tns.signersCount = tns.signersCount + 1;

        hasSigned[_txId][msg.sender] = true;

        if (tns.signersCount == quorum) {
            tns.isExecuted = true;
            payable(tns.receiver).transfer(tns.amount);
        }
    }

    function transferOwnership(address _newOwner) external {
        onlyOwner();

        nextOwner = _newOwner;
    }

    function claimOwnership() external {
        require(msg.sender == nextOwner, "not next owner");

        owner = msg.sender;

        nextOwner = address(0);
    }

    function addValidSigner(address _newSigner) external {
        onlyOwner();

        require(!isValidSigner[_newSigner], "signer already exist");

        isValidSigner[_newSigner] = true;
        signers.push(_newSigner);
    }

    function removeSigner(uint _index) external {
        onlyOwner();
        require(_index < signers.length, "Invalid index");

        signers[_index] = signers[signers.length - 1];

        isValidSigner[signers[_index]] = false;

        signers.pop();
    }

    function getAllTransactions() external view returns (Transaction[] memory) {
        return allTransactions;
    }

    function onlyOwner() private view {
        require(msg.sender == owner, "not owner");
    }

    function onlyValidSigner() private view {
        require(isValidSigner[msg.sender], "not valid signer");
    }

    //these two methods below makes it possble for this contract to receive ether
    receive() external payable {}

    fallback() external payable {}
}