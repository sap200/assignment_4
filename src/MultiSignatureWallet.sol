// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

contract MultiSignatureWallet {
    enum TransactionState {
        PENDING,
        EXECUTED,
        CANCELLED
    }

    struct Transaction {
        address creator;
        address to;
        uint256 value;
        uint256 approvalCount;
        bytes data;
        TransactionState transactionState;
    }

    uint256 public executionThreshold;
    string public name;

    // List of all transactions for transparency
    Transaction[] public transactions;
    address[] public owners;
    mapping(address => bool) public isOwner;
    // txnId => owners => approvals (true/false)
    mapping(uint256 => mapping(address => bool)) public approvals;

    event DepositedEther(address indexed depositor, uint256 amount);
    event WithdrawnEther(address indexed withdrawer, uint256 amount);
    event TransactionSubmitted(
        address indexed creator,
        uint256 transactionIndex
    );
    event TransactionApproved(
        address indexed approver,
        uint256 transactionIndex
    );
    event TransactionCancelled(
        address indexed cancellor,
        uint256 transactionIndex
    );
    event TransactionExecuted(
        address indexed executor,
        uint256 transactionIndex
    );

    modifier onlyOwner() {
        require(isOwner[msg.sender] == true, "Msg sender is not an owner");
        _;
    }

    modifier isTransactionPending(uint256 _txnIdx) {
        require(
            transactions[_txnIdx].transactionState == TransactionState.PENDING,
            "Transaction state is not pending"
        );
        _;
    }

    modifier isExecutionAllowed(uint256 _txnIdx) {
        require(
            transactions[_txnIdx].approvalCount >= executionThreshold,
            "Execution not allowed"
        );
        _;
    }

    modifier isExistingTransaction(uint256 _txnIdx) {
        require(_txnIdx < transactions.length, "Invalid txn id");
        _;
    }

    modifier hasNotProvidedApprovalYet(uint256 _txnIdx) {
        require(
            approvals[_txnIdx][msg.sender] == false,
            "Approval already provided"
        );
        _;
    }

    constructor(
        string memory _name,
        address[] memory _owners,
        uint256 _executionThreshold
    ) {
        require(_owners.length >= 1, "At least 1 owner required");
        require(
            _executionThreshold > 0 && _executionThreshold <= _owners.length,
            "Execution threshold cannot be greater than length of list of owners"
        );
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid address provided");
            require(isOwner[_owners[i]] == false, "Duplicate owner provided");
            owners.push(_owners[i]);
            isOwner[_owners[i]] = true;
        }
        executionThreshold = _executionThreshold;
        name = _name;
    }

    receive() external payable {
        emit DepositedEther(msg.sender, msg.value);
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) external payable onlyOwner {
        uint256 _txnIdx = transactions.length;
        Transaction memory transaction;
        transaction.creator = msg.sender;
        transaction.to = _to;
        transaction.value = _value;
        transaction.transactionState = TransactionState.PENDING;
        transaction.data = _data;
        transaction.approvalCount = 1;
        transactions.push(transaction);

        // if an owner submits txn, it means we already have his approval
        approvals[_txnIdx][msg.sender] = true;

        emit TransactionSubmitted(msg.sender, _txnIdx);
    }

    function approveTransaction(uint256 _txnIdx)
        external
        onlyOwner
        isExistingTransaction(_txnIdx)
        isTransactionPending(_txnIdx)
        hasNotProvidedApprovalYet(_txnIdx)
    {
        transactions[_txnIdx].approvalCount++;
        approvals[_txnIdx][msg.sender] = true;
        emit TransactionApproved(msg.sender, _txnIdx);
    }

    function cancelTransaction(uint256 _txnIdx)
        external
        onlyOwner
        isExistingTransaction(_txnIdx)
        isTransactionPending(_txnIdx)
    {
        transactions[_txnIdx].transactionState = TransactionState.CANCELLED;
        emit TransactionCancelled(msg.sender, _txnIdx);
    }

    function executeTransaction(uint256 _txnIdx)
        external
        onlyOwner
        isExistingTransaction(_txnIdx)
        isTransactionPending(_txnIdx)
        isExecutionAllowed(_txnIdx)
    {
        require(
            address(this).balance >= transactions[_txnIdx].value,
            "Insufficient contract balance"
        );
        Transaction memory _transaction = transactions[_txnIdx];
        // execute txn
        (bool ok, ) = _transaction.to.call{value: _transaction.value}(
            _transaction.data
        );
        require(ok, "Transaction execution failed");
        // update txn status
        transactions[_txnIdx].transactionState = TransactionState.EXECUTED;

        emit TransactionExecuted(msg.sender, _txnIdx);
    }

    function withdrawEthers(address recipient, uint256 amount) external {
        require(
            msg.sender == address(this),
            "Only contract can allow withdrawl"
        );
        require(address(this).balance >= amount, "Insufficient balance");
        payable(recipient).transfer(amount);
        emit WithdrawnEther(recipient, amount);
    }

    function viewAllTransactions()
        external
        view
        returns (Transaction[] memory)
    {
        return transactions;
    }

    function viewAllOwners() external view returns (address[] memory) {
        return owners;
    }
}
