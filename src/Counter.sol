// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Counter {
    uint256 public number;

    function setNumber(uint256 newNumber) public payable {
        number = newNumber;
    }

    function increment() public {
        number++;
    }

    function getDataForSetNumber(uint256 _newNumber) public pure returns (bytes memory) {
        return abi.encodeWithSignature("setNumber(uint256)", _newNumber);
    }

    function getDataForIncrement() public pure returns (bytes memory) {
        return abi.encodeWithSignature("increment()");
    }
}
