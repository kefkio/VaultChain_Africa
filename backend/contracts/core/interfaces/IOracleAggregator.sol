// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IOracleAggregator {
    function version() external pure returns (string memory);

    // Add public/external Oracle functions
    // e.g.,
    // function getPrice(address asset) external view returns (uint256);
}
