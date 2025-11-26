// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../loan/LoanCore.sol";
import "../loan/LoanTypes.sol";
import "../core/interfaces/IInsuranceCalculator.sol";


/// @title SimpleInsuranceCalculator
/// @notice Calculates insurance as a flat annual percentage of the loan principal, prorated by time
contract SimpleInsuranceCalculator is IInsuranceCalculator {
    using LoanTypes for *;

    LoanCore public immutable loanCore;

    /// @notice Annual insurance rate in basis points (e.g. 200 = 2% per year)
    uint256 public annualInsuranceRateBps;

    event AnnualInsuranceRateUpdated(uint256 oldRateBps, uint256 newRateBps);

    constructor(address _loanCore, uint256 _annualInsuranceRateBps) {
        loanCore = LoanCore(_loanCore);
        annualInsuranceRateBps = _annualInsuranceRateBps;
    }

    /**
     * @notice Set annual insurance rate in basis points (e.g. 200 = 2%)
     * @dev Add onlyOwner/onlyAdmin modifier once you have your access-control pattern
     */
    function setAnnualInsuranceRateBps(uint256 _annualInsuranceRateBps) external {
        // TODO: add access control (e.g. onlyOwner / onlyRole)
        emit AnnualInsuranceRateUpdated(annualInsuranceRateBps, _annualInsuranceRateBps);
        annualInsuranceRateBps = _annualInsuranceRateBps;
    }

    /**
     * @inheritdoc IInsuranceCalculator
     */
    function premiumForPeriod(uint256 loanId, uint256 period)
    external
    view
    override
    returns (uint256 premium)
{
(
    ,
    ,
    ,
    uint256 amount,
    ,
    ,
    ,
    LoanTypes.LoanStatus status
) = loanCore.getLoanDetails(loanId);


    require(amount > 0, "InsuranceCalculator: loan amount is zero");
    require(period > 0, "InsuranceCalculator: period must be > 0");
    require(status == LoanTypes.LoanStatus.Active, "InsuranceCalculator: loan not active");

    uint256 yearlyPremium = (amount * annualInsuranceRateBps) / 10_000;
    premium = (yearlyPremium * period) / 365 days;
}
}
