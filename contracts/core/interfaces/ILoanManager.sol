// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ILoanManager {
    // -----------------------------
    // Member Registration & KYC
    // -----------------------------
    function registerMember() external;
    function registerMemberFor(address member) external;
    function updateKyc(address member, uint8 status) external;

    // -----------------------------
    // Loan Lifecycle
    // -----------------------------
    function requestLoan(
        uint256 amount,
        uint8 paymentType,
        address tokenAddress,
        uint256 guarantorCount,
        uint256 duration,
        address[] memory guarantors
    ) external returns (uint256);

    function approveLoan(uint256 loanId) external;
    function disburseLoan(uint256 loanId) external;
    function repayLoan(uint256 loanId, uint256 amount) external payable;
    function markDefault(uint256 loanId) external;

    // -----------------------------
    // View Functions
    // -----------------------------
    function getLoanDetails(uint256 loanId)
        external
        view
        returns (
            address borrower,
            uint8 paymentType,
            address tokenAddress,
            uint256 guarantorCount,
            uint256 amount,
            uint256 interestRate,
            uint256 duration,
            uint256 dueDate,
            uint8 status
        );

    function getKycStatus(address member) external view returns (uint8);
    function isRegistered(address member) external view returns (bool);
    function getActiveLoanId(address borrower) external view returns (uint256);
}
