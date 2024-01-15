// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";
import {MultiSignatureWallet} from "../src/MultiSignatureWallet.sol";


contract MultiSignatureWalletTest is Test {
    MultiSignatureWallet public multiSignatureWallet;
    Counter public counter;
    address account1;
    address account2;
    address account3;
    address account4;
    address[] xadr;


    function setUp() public {
        counter = new Counter();

        account1 = vm.addr(1);
        account2 = vm.addr(2);
        account3 = vm.addr(3);
        account4 = vm.addr(4);

        vm.deal(account1, 100 ether);
        vm.deal(account2, 100 ether);
        vm.deal(account3, 100 ether);
        vm.deal(account4, 100 ether);

        xadr.push(account1);
        xadr.push(account2);
        xadr.push(account3);

        multiSignatureWallet = new MultiSignatureWallet("T_WALLET", xadr, 2);
    }

    // TestDescription: Owner submits a transaction
    // Expected: The transaction is stored in the transactions lists
    function test_SubmitTransactionByOwner() public {
        bytes memory data = counter.getDataForSetNumber(12);
        vm.expectEmit(true, false, false, true, address(multiSignatureWallet));
        emit MultiSignatureWallet.TransactionSubmitted(account1, 0);
        vm.prank(account1);
        multiSignatureWallet.submitTransaction{value: 5 ether}(address(counter), 5 ether, data);

        assertTrue(multiSignatureWallet.approvals(0, account1));
        (address _creator, address _to, uint256 _value, uint256 _approvalCount, bytes memory _data, MultiSignatureWallet.TransactionState _transactionState) = multiSignatureWallet.transactions(0);
        
        // assertions
        assertEq(_creator, account1);
        assertEq(_to, address(counter));
        assertEq(_value, 5 ether);
        assertEq(_approvalCount, 1);
        assertEq(_data, data);
        assertTrue(_transactionState == MultiSignatureWallet.TransactionState.PENDING);
        assertEq(address(multiSignatureWallet).balance, 5 ether);
        assertEq(address(account1).balance, 95 ether);
    }

    // TestDescription: NonOwner submits a transaction
    // Expected: Only owner can submit a txn and hence VM reverts with an error
    function test_submitTransactionByNonOwner() public {
        bytes memory data = counter.getDataForIncrement();
        vm.expectRevert("Msg sender is not an owner");
        vm.prank(account4);
        multiSignatureWallet.submitTransaction(address(counter), 0, data);
    }

    // TestDescription: Owner approves a txn in pending state that wasn't approved by the same owner before
    // Expected: Owner is able to successfully approve the transaction, the approvalCount and approvals mapping is updated
    function test_approveATransactionByNewOwner() public {
        // account 1 submits a transaction
        bytes memory data = counter.getDataForSetNumber(12);
        vm.prank(account1);
        multiSignatureWallet.submitTransaction{value: 5 ether}(address(counter), 5 ether, data);   


        // account2 approves the transaction
        vm.expectEmit(true, false, false, true, address(multiSignatureWallet));
        emit MultiSignatureWallet.TransactionApproved(account2, 0);
        vm.prank(account2);
        multiSignatureWallet.approveTransaction(0);

        (, , ,uint256 _approvalCount, ,) = multiSignatureWallet.transactions(0);

        // assertions
        assertEq(_approvalCount, 2);
        assertTrue(multiSignatureWallet.approvals(0, account2));
    }

    // TestDescription: Non Owner tries to approve the transaction
    // Expected: We expect the VM to revert with message Msg sender is not the owner
    function test_approveTransactionByNonOwner() public {
        // account 1 submits a transaction
        bytes memory data = counter.getDataForSetNumber(12);
        vm.prank(account1);
        multiSignatureWallet.submitTransaction{value: 5 ether}(address(counter), 5 ether, data);   

        // account4 tries to approve
        vm.expectRevert("Msg sender is not an owner");
        vm.prank(account4);
        multiSignatureWallet.approveTransaction(0);


        (, , ,uint256 _approvalCount, ,) = multiSignatureWallet.transactions(0);

        // assertions
        assertEq(_approvalCount, 1);
        assertFalse(multiSignatureWallet.approvals(0, account4));    
    }

    // TestDescription: An Owner tries to approve a non-existing transaction
    // Expected: We expect VM to revert with an error message
    function test_approveTransactionForNonExistingTransaction() public {
        // account1 tries to approve
        vm.expectRevert("Invalid txn id");
        vm.prank(account1);
        multiSignatureWallet.approveTransaction(0);
    }

    // TestDescription: Owner has already approved a transaction, but he tries to approve it again
    // Expected: We expect VM to revert with an error message
    function test_approveTransactionByOwnerWhoAlreadyApprovedTheSameTransaction() public {
        // account 1 submits a transaction
        bytes memory data = counter.getDataForSetNumber(12);
        vm.prank(account1);
        multiSignatureWallet.submitTransaction{value: 5 ether}(address(counter), 5 ether, data);   

        // account2 tries to approve
        vm.prank(account2);
        multiSignatureWallet.approveTransaction(0);

        // account2 tries to approve the transaction again
        vm.expectRevert("Approval already provided");
        vm.prank(account2);
        multiSignatureWallet.approveTransaction(0);

        
        (, , ,uint256 _approvalCount, ,) = multiSignatureWallet.transactions(0);

        // assertions
        assertEq(_approvalCount, 2);
        assertTrue(multiSignatureWallet.approvals(0, account2));
    }

    // TestDescription: Owner tries to approve the transaction that is not in PENDING state
    // Expected: We expect the VM to revert with an error message
    function test_approveTransactionThatIsNotInPendingState() public {
        // account 1 submits a transaction
        bytes memory data = counter.getDataForSetNumber(12);
        vm.prank(account1);
        multiSignatureWallet.submitTransaction{value: 5 ether}(address(counter), 5 ether, data);   

        // account2 cancels the transaction
        vm.prank(account2);
        multiSignatureWallet.cancelTransaction(0);

        // account3 tries to approve the cancelled transaction
        vm.expectRevert("Transaction state is not pending");
        vm.prank(account3);
        multiSignatureWallet.approveTransaction(0);

        // asserts
        (, , , uint256 _approvalCount, , MultiSignatureWallet.TransactionState txnState) = multiSignatureWallet.transactions(0);
        assertTrue(txnState == MultiSignatureWallet.TransactionState.CANCELLED);
        assertEq(_approvalCount, 1);
    }

    // TestDescription: Owner tries to cancel a transaction
    // Expected: The transaction state is changed to cancelled
    function test_cancelTransactionByOwner() public {
        // account 1 submits a transaction
        bytes memory data = counter.getDataForSetNumber(12);
        vm.prank(account1);
        multiSignatureWallet.submitTransaction{value: 5 ether}(address(counter), 5 ether, data);   

        // account2 cancels the transaction
        vm.expectEmit(true, false, false, true, address(multiSignatureWallet));
        emit MultiSignatureWallet.TransactionCancelled(account2, 0);
        vm.prank(account2);
        multiSignatureWallet.cancelTransaction(0);    


        // asserts
        (, , , uint256 _approvalCount, , MultiSignatureWallet.TransactionState txnState) = multiSignatureWallet.transactions(0);
        assertTrue(txnState == MultiSignatureWallet.TransactionState.CANCELLED);
        assertEq(_approvalCount, 1);   
    }

    // TestDescription: Non owner tries to cancel the transaction
    // Expected: VM reverts with an error
    function test_cancelTransactionByNonOwner() public {
        // account 1 submits a transaction
        bytes memory data = counter.getDataForSetNumber(12);
        vm.prank(account1);
        multiSignatureWallet.submitTransaction{value: 5 ether}(address(counter), 5 ether, data);   

        // account4 cancels the transaction
        vm.expectRevert("Msg sender is not an owner");
        vm.prank(account4);
        multiSignatureWallet.cancelTransaction(0);    

        // asserts
        (, , , , , MultiSignatureWallet.TransactionState txnState) = multiSignatureWallet.transactions(0);
        assertTrue(txnState == MultiSignatureWallet.TransactionState.PENDING);
    }

    // TestDescription: Owner tries to cancel a non existing transaction
    // Expected: We expect the VM to revert with an error
    function test_cancelTransactionWhichIsNonExisting() public {
        // account4 cancels the transaction
        vm.expectRevert("Invalid txn id");
        vm.prank(account1);
        multiSignatureWallet.cancelTransaction(0);  
    }

    // TestDescription: Owner tries to cancel a transaction that is not in pending state
    // Expected: We expect the VM to revert with an error
    function test_cancelTransactionWhichIsNotInPendingState() public {
        // account 1 submits a transaction
        bytes memory data = counter.getDataForSetNumber(12);
        vm.prank(account1);
        multiSignatureWallet.submitTransaction{value: 5 ether}(address(counter), 5 ether, data);   

        // account2 cancels the transaction
        vm.prank(account2);
        multiSignatureWallet.cancelTransaction(0);    

        // account2 tries to cancel the transaction again
        vm.expectRevert("Transaction state is not pending");
        vm.prank(account2);
        multiSignatureWallet.cancelTransaction(0);    
    }

    // TestDescription: Owner tries to execute a transaction that is executable
    // Expected: We expect the transaction to be executed successfully
    function test_executeATransactionByOwner() public {
        // account 1 submits a transaction
        bytes memory data = counter.getDataForSetNumber(12);
        vm.prank(account1);
        multiSignatureWallet.submitTransaction{value: 5 ether}(address(counter), 5 ether, data); 

        // account2 approves it
        vm.prank(account2);
        multiSignatureWallet.approveTransaction(0);      

        // Initial state tracking
        uint256 initialBalanceOfMultiSignatureWalletContract = address(multiSignatureWallet).balance;
        uint256 initialBalanceOfCounterContract = address(counter).balance;

        // account 3 executes the transaction
        vm.expectEmit(true, false, false, true, address(multiSignatureWallet));
        emit MultiSignatureWallet.TransactionExecuted(account3, 0);
        vm.prank(account3);
        multiSignatureWallet.executeTransaction(0);

        // final state tracking
        uint256 finalBalanceOfMultiSignatureWallet = address(multiSignatureWallet).balance;
        uint256 finalBalanceOfCounterContract = address(counter).balance;
        (, , , , , MultiSignatureWallet.TransactionState txnState) = multiSignatureWallet.transactions(0);
        
        // asserts
        assertTrue(txnState == MultiSignatureWallet.TransactionState.EXECUTED);
        assertEq(finalBalanceOfMultiSignatureWallet, initialBalanceOfMultiSignatureWalletContract - 5 ether);
        assertEq(finalBalanceOfCounterContract, initialBalanceOfCounterContract + 5 ether);
        assertEq(counter.number(), 12);    
    }

    // TestDescription: Non owner tries to execute a transaction
    // Expected: We expect the transaction to fail
    function test_executeTransactionByNonOwner() public {
        // account 1 submits a transaction
        bytes memory data = counter.getDataForSetNumber(12);
        vm.prank(account1);
        multiSignatureWallet.submitTransaction{value: 5 ether}(address(counter), 5 ether, data); 

        // account2 approves it
        vm.prank(account2);
        multiSignatureWallet.approveTransaction(0);     

        vm.expectRevert("Msg sender is not an owner");
        vm.prank(account4);
        multiSignatureWallet.executeTransaction(0); 

        (, , , , , MultiSignatureWallet.TransactionState txnState) = multiSignatureWallet.transactions(0);
        assertTrue(txnState == MultiSignatureWallet.TransactionState.PENDING);
    }

    // TestDescription: Owner tries to execute a non existing transaction
    // Expected: The transaction is unsuccessfull and vm reverts with an error message
    function test_executeNonExistingTransaction() public {
        vm.expectRevert("Invalid txn id");
        vm.prank(account1);
        multiSignatureWallet.executeTransaction(0);
    }

    // TestDescription: Owner tries to execute a transaction that is already executed
    // Expected: We expect the vm to revert
    function test_executeAlreadyExecutedTransaction() public {
        // account 1 submits a transaction
        bytes memory data = counter.getDataForSetNumber(12);
        vm.prank(account1);
        multiSignatureWallet.submitTransaction{value: 5 ether}(address(counter), 5 ether, data); 

        // account 2 approves it
        vm.prank(account2);
        multiSignatureWallet.approveTransaction(0);

        // account 1 executes the transaction
        vm.prank(account1);
        multiSignatureWallet.executeTransaction(0);

        // account 1 tries to execute the transaction
        vm.expectRevert("Transaction state is not pending");
        vm.prank(account1);
        multiSignatureWallet.executeTransaction(0);

        (, , , , , MultiSignatureWallet.TransactionState txnState) = multiSignatureWallet.transactions(0);
        assertTrue(txnState == MultiSignatureWallet.TransactionState.EXECUTED);
    }

    
    // TestDescription: Owner tries to execute a transaction that is cancelled
    // Expected: We expect the vm to revert
    function test_executeCancelledTransaction() public {
        // account 1 submits a transaction
        bytes memory data = counter.getDataForSetNumber(12);
        vm.prank(account1);
        multiSignatureWallet.submitTransaction{value: 5 ether}(address(counter), 5 ether, data); 

        // account 2 approves it
        vm.prank(account2);
        multiSignatureWallet.cancelTransaction(0);

        // account 1 tries to execute the transaction
        vm.expectRevert("Transaction state is not pending");
        vm.prank(account1);
        multiSignatureWallet.executeTransaction(0);

        (, , , , , MultiSignatureWallet.TransactionState txnState) = multiSignatureWallet.transactions(0);
        assertTrue(txnState == MultiSignatureWallet.TransactionState.CANCELLED);
    }

    // TestDescription: Owner tries to execute a transaction with insufficient approvals
    // Expected: We expect the vm to revert
    function test_executeTransactionWithInsufficientApprovals() public {
        // account 1 submits a transaction
        bytes memory data = counter.getDataForSetNumber(12);
        vm.prank(account1);
        multiSignatureWallet.submitTransaction{value: 5 ether}(address(counter), 5 ether, data);    

        // account 1 tries to execute the transaction
        vm.expectRevert("Execution not allowed");
        vm.prank(account1);
        multiSignatureWallet.executeTransaction(0);

        (, , , , , MultiSignatureWallet.TransactionState txnState) = multiSignatureWallet.transactions(0);
        assertTrue(txnState == MultiSignatureWallet.TransactionState.PENDING);
    }

    // TestDescription: Owner tries to execute a transaction but contract has insufficient balance to execute the transaction
    // Expected: We expect the vm to revert
    function test_executeTransactionWithInsufficientFunds() public {
        // account 1 submits a transaction
        bytes memory data = counter.getDataForSetNumber(12);
        vm.prank(account1);
        multiSignatureWallet.submitTransaction(address(counter), 5 ether, data);    

        // account 2 approves the transaction
        vm.prank(account2);
        multiSignatureWallet.approveTransaction(0);

        // account 1 tries to execute the transaction
        vm.expectRevert("Insufficient contract balance");
        vm.prank(account1);
        multiSignatureWallet.executeTransaction(0);
    }

    // TestDescription: owner tries to execute an invalid transaction that was submitted
    // Expected: We expect the VM to revert
    function test_executeInvalidTransaction() public {
        bytes memory data;
        vm.prank(account1);
        multiSignatureWallet.submitTransaction{value: 5 ether}(address(counter), 5 ether, data);    

        // account 2 approves the transaction
        vm.prank(account2);
        multiSignatureWallet.approveTransaction(0);

        // account 1 tries to execute the transaction
        vm.expectRevert("Transaction execution failed");
        vm.prank(account1);
        multiSignatureWallet.executeTransaction(0);

        (, , , , , MultiSignatureWallet.TransactionState txnState) = multiSignatureWallet.transactions(0);
        assertTrue(txnState == MultiSignatureWallet.TransactionState.PENDING);
    }

    // TestDescription: owner tries to deposit certain amount of ethers to multisignature wallet contract
    // Expected: The transaction is executed successfully and the balance of the contract increases
    function test_depositEthersToMultiSignatureWalletContract() public {
        vm.expectEmit(true, false, false, true, address(multiSignatureWallet));
        emit MultiSignatureWallet.DepositedEther(account2, 5 ether);
        vm.startPrank(account2);
        payable(address(multiSignatureWallet)).transfer(5 ether);
        vm.stopPrank();

        assertEq(address(multiSignatureWallet).balance, 5 ether);
        assertEq(account2.balance, 95 ether);
    }

    // TestDescription: Owner submits a transaction to withdraw ethers by submitting a transaction
    // Expected: Owner receives ether
    function test_etherWithdrawlUsingTransactionSubmission() public {
        // account 1 submits a transaction and sends 5 ether during submission
        bytes memory data = abi.encodeWithSignature("withdrawEthers(address,uint256)", account4, 5 ether);
        vm.prank(account1);
        multiSignatureWallet.submitTransaction(address(multiSignatureWallet), 0, data);    

        // deposit 5 ethers in the contract
        vm.startPrank(account2);
        payable(address(multiSignatureWallet)).transfer(5 ether);
        vm.stopPrank();

        // account2 approves the txn
        vm.prank(account2);
        multiSignatureWallet.approveTransaction(0);

        // account1 executes the transaction
        vm.expectEmit(true, false, false, true, address(multiSignatureWallet));
        emit MultiSignatureWallet.WithdrawnEther(account4, 5 ether);
        vm.prank(account1);
        multiSignatureWallet.executeTransaction(0);

        // assertions
        assertEq(account4.balance, 105 ether);
        assertEq(address(multiSignatureWallet).balance, 0 ether);
    }

    // TestDescription: Owner submits a transaction to withdraw ethers from contract but contract has insufficient balance
    // Expected: VM reverts with an error
    function test_etherWithdrawlWithInsufficientContractBalance() public {

        // account 1 submits a transaction and sends 5 ether during submission
        bytes memory data = abi.encodeWithSignature("withdrawEthers(address,uint256)", account4, 5 ether);
        vm.prank(account1);
        multiSignatureWallet.submitTransaction(address(multiSignatureWallet), 0, data);    

        // account2 approves the txn
        vm.prank(account2);
        multiSignatureWallet.approveTransaction(0);

        // account1 executes the transaction
        vm.expectRevert("Transaction execution failed");
        vm.prank(account1);
        multiSignatureWallet.executeTransaction(0);

        (, , , , , MultiSignatureWallet.TransactionState txnState) = multiSignatureWallet.transactions(0);
        assertTrue(txnState == MultiSignatureWallet.TransactionState.PENDING);
        assertEq(account4.balance, 100 ether);
    }

    // TestDescription: owner tries to directly withdraw ethers without submitting a transaction
    // Expected: VM reverts with an error
    function test_withdrawEthersDirectlyWithoutSubmittingATransaction() public {
        // deposit 5 ethers in the contract
        vm.startPrank(account2);
        payable(address(multiSignatureWallet)).transfer(5 ether);
        vm.stopPrank();

        vm.expectRevert("Only contract can allow withdrawl");
        vm.prank(account1);
        multiSignatureWallet.withdrawEthers(account4, 5 ether);

        assertEq(account4.balance, 100 ether);
        assertEq(address(multiSignatureWallet).balance, 5 ether);
    }
}