// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./LoanTypes.sol";
import "./LoanCore.sol";
import "./LoanGuarantors.sol";

/// @title LoanLogic
/// @notice Orchestrates loan lifecycle by coordinating LoanCore and LoanGuarantors
contract LoanLogic is AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    LoanCore public loanCore;
    LoanGuarantors public loanGuarantors;

    // ---------- Constructor ----------
    constructor(address _loanCore, address _loanGuarantors, address admin) {
        require(_loanCore != address(0), "LoanLogic: loanCore zero");
        require(_loanGuarantors != address(0), "LoanLogic: guarantors zero");
        require(admin != address(0), "LoanLogic: admin zero");

        loanCore = LoanCore(_loanCore);
        loanGuarantors = LoanGuarantors(_loanGuarantors);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
    }

    // ---------- KYC ----------
    function updateKyc(address member, LoanTypes.KycStatus status)
        external
        onlyRole(OPERATOR_ROLE)
    {
        loanCore.setKycStatus(member, status);
    }

    function getKycStatus(address member) external view returns (LoanTypes.KycStatus) {
        return loanCore.getKycStatus(member);
    }

    // ---------- Loan Creation ----------
    function createLoan(
        address borrower,
        uint256 amount,
        uint256 duration,
        uint256 interestRateBps,
        uint256 borrowerCollateralAmount,
        address borrowerCollateralToken,
        LoanTypes.PaymentType paymentType,
        address tokenAddress,
        address[] calldata guarantors_
    ) external nonReentrant returns (uint256 loanId) {
        loanId = loanCore.createLoan(
            borrower,
            amount,
            duration,
            interestRateBps,
            borrowerCollateralAmount,
            borrowerCollateralToken,
            paymentType,
            tokenAddress,
            LoanTypes.LoanType.Personal // adjust if you want dynamic loanType
        );

        for (uint256 i = 0; i < guarantors_.length; i++) {
            loanGuarantors.addGuarantor(loanId, guarantors_[i]);
        }
    }

    // ---------- Repayment ----------
    function repayLoan(uint256 loanId, uint256 amount, address _payer)
        external
        payable
        nonReentrant
    {
        loanCore.reduceLoanAmount(loanId, amount);
        // If PaymentType.Native, msg.value can be forwarded to Treasury here
    }

    // ---------- Status Transitions ----------
    function approveLoan(uint256 loanId) external onlyRole(OPERATOR_ROLE) {
        loanCore.updateLoanStatus(loanId, LoanTypes.LoanStatus.Approved);
    }

    function disburseLoan(uint256 loanId) external onlyRole(OPERATOR_ROLE) {
        loanCore.updateLoanStatus(loanId, LoanTypes.LoanStatus.Disbursed);
    }

    function markDefault(uint256 loanId) external onlyRole(OPERATOR_ROLE) {
        loanCore.updateLoanStatus(loanId, LoanTypes.LoanStatus.Defaulted);
    }

    // ---------- Guarantor Acceptance ----------
    function acceptGuarantorRole(uint256 loanId) external {
        loanGuarantors.acceptGuarantorRole(loanId);
    }

    // ---------- Unified Loan Details ----------
    function getLoanDetails(uint256 loanId)
        external
        view
        returns (
            address borrower,
            LoanTypes.PaymentType paymentType,
            address tokenAddress,
            uint256 guarantorCount,
            uint256 amount,
            uint256 interestRate,
            uint256 duration,
            uint256 dueDate,
            LoanTypes.LoanStatus status
        )
    {
        LoanTypes.Loan memory loan = loanCore.getLoan(loanId);
        borrower = loan.borrower;
        paymentType = loan.profile.paymentType;
        tokenAddress = loan.tokenAddress;
        guarantorCount = loanGuarantors.getGuarantorCount(loanId);
        amount = loan.amount;
        interestRate = loan.interestRateBps;
        duration = loan.duration;
        dueDate = loan.dueDate;
        status = loan.status;
    }
}