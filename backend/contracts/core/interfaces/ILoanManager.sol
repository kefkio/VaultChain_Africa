// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./IMembership.sol";

interface ILoanManager {
    enum KycStatus { Pending, Verified, Rejected }
    enum PaymentType { Native, Fiat, Token }
    enum LoanStatus { Requested, Guaranteed, Approved, Disbursed, PartiallyRepaid, FullyRepaid, Repaid, Defaulted }

    struct Loan {
        address borrower;
        PaymentType paymentType;
        address tokenAddress;
        uint256 amount;
        uint256 interestRate;
        uint256 duration;
        uint256 dueDate;
        LoanStatus status;
        address[] guarantors;
    }

    function registerMember() external;
    function requestLoan(
        uint256 amount,
        PaymentType paymentType,
        address tokenAddress,
        uint256 guarantorCount,
        uint256 duration,
        address[] memory guarantors
    ) external returns (uint256);

    function approveLoan(uint256 loanId) external;
    function disburseLoan(uint256 loanId) external;
    function repayLoan(uint256 loanId, uint256 amount) external payable;

    function getLoanDetails(uint256 loanId) external view returns (
        address borrower,
        PaymentType paymentType,
        address tokenAddress,
        uint256 guarantorCount,
        uint256 amount,
        uint256 interestRate,
        uint256 duration,
        uint256 dueDate,
        LoanStatus status
    );
}
