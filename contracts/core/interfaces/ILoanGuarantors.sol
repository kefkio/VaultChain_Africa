// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;


import "../../loan/LoanTypes.sol";

interface ILoanGuarantors {
    function getGuarantorCount(uint256 loanId) external view returns (uint256);
    function acceptGuarantorRole(uint256 loanId) external;
    function addGuarantor(uint256 loanId, address guarantor) external;
}