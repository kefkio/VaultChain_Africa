// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract FeeManager {
    mapping(address => uint256) public totalFees;
    uint256 public protocolFeeRate = 50; // 0.5% in basis points

    function recordFee(address wallet, uint256 feeAmount) external {
        totalFees[wallet] += feeAmount;
    }

    function calculateFee(uint256 txValue) public view returns (uint256) {
        return (txValue * protocolFeeRate) / 10000;
    }
}