// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IInsuranceCalculator
/// @notice Interface for calculating insurance premiums for loans
interface IInsuranceCalculator {
    /**
     * @notice Returns the insurance premium for a given loan over a specific period.
     * @param loanId The ID of the loan.
     * @param period Duration in seconds (e.g. 180 days for 6 months).
     * @return premium Amount of insurance premium in the loan's currency units (e.g. wei).
     */
    function premiumForPeriod(uint256 loanId, uint256 period)
        external
        view
        returns (uint256 premium);
}
