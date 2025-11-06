// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ITimelockController {
    function version() external pure returns (string memory);

    // Add public/external Timelock functions
    // e.g.,
    // function schedule(address target, uint256 value, bytes calldata data, bytes32 salt, uint256 delay) external;
    // function execute(address target, uint256 value, bytes calldata data, bytes32 salt) external;
}
