// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IFeeManager {
    function recordFee(address wallet, uint256 feeAmount) external;
    function calculateFee(uint256 txValue) external view returns (uint256);
    function verifyFee(address wallet, uint256 feeAmount) external view returns (bool);
}