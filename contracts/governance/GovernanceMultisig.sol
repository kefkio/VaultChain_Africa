// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract GovernanceMultisig {
    TimelockController public timelock;

    // Example additional state variables
    address[] public owners;
    uint256 public threshold;

    // ---------- Constructor ----------
    /// @param _timelock The address of the deployed TimelockController contract
    /// @param _owners Array of multisig owners
    /// @param _threshold Number of approvals required
    constructor(
        address _timelock,
        address[] memory _owners,
        uint256 _threshold
    ) {
        require(_timelock != address(0), "Invalid timelock address");
        require(_threshold > 0 && _threshold <= _owners.length, "Invalid threshold");
        require(_owners.length > 0, "Owners required");

        // Assign timelock contract with payable cast
        timelock = TimelockController(payable(_timelock));

        // Initialize owners and threshold
        owners = _owners;
        threshold = _threshold;
    }

    // Example function to check timelock address
    function getTimelock() external view returns (address) {
        return address(timelock);
    }
}
