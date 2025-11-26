// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./LoanTypes.sol";

/// @title LoanCore
/// @notice Stores loans, KYC info, and handles core loan operations
contract LoanCore is AccessControl {
    bytes32 public constant CORE_ROLE = keccak256("CORE_ROLE");
    bytes32 public constant LOGIC_ROLE = keccak256("LOGIC_ROLE");

    uint256 private _nextLoanId = 1;

    // ---------- Storage ----------
    mapping(uint256 => LoanTypes.Loan) private _loans;        // loanId => Loan
    mapping(address => LoanTypes.KycStatus) private _kyc;     // member => KYC status

    // ---------- Events ----------
    event LoanCreated(uint256 indexed loanId, address indexed borrower);
    event LoanRepaid(uint256 indexed loanId, uint256 amount, address indexed payer);
    event LoanStatusUpdated(
        uint256 indexed loanId,
        LoanTypes.LoanStatus oldStatus,
        LoanTypes.LoanStatus newStatus
    );
    event KycUpdated(address indexed member, LoanTypes.KycStatus status);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Option 1: admin is also core / logic for now
        _grantRole(CORE_ROLE, msg.sender);
        _grantRole(LOGIC_ROLE, msg.sender);
    }

    // ---------- Modifiers ----------
    modifier onlyCore() {
        // Either CORE_ROLE or LOGIC_ROLE can act as "core"
        require(
            hasRole(CORE_ROLE, msg.sender) || hasRole(LOGIC_ROLE, msg.sender),
            "LoanCore: caller not authorized"
        );
        _;
    }

    // ---------- Loan Functions ----------
    function createLoan(
        address borrower,
        uint256 amount,
        uint256 duration,
        uint256 interestRateBps,
        uint256 borrowerCollateralAmount,
        address borrowerCollateralToken,
        LoanTypes.PaymentType paymentType,
        address tokenAddress,
        LoanTypes.LoanType loanType
    ) external onlyCore returns (uint256 loanId) {
        require(borrower != address(0), "LoanCore: borrower is zero");
        require(amount > 0, "LoanCore: amount is zero");
        require(duration > 0, "LoanCore: duration is zero");

        loanId = _nextLoanId++;

        LoanTypes.Loan memory loan;
        loan.borrower = borrower;
        loan.amount = amount;
        loan.duration = duration;
        loan.interestRateBps = interestRateBps; // <-- match struct field
        loan.borrowerCollateralAmount = borrowerCollateralAmount;
        loan.borrowerCollateralToken = borrowerCollateralToken;

        loan.profile = LoanTypes.LoanProfile({
            loanType: loanType,
            paymentType: paymentType,
            collateralType: borrowerCollateralToken == address(0)
                ? LoanTypes.CollateralType.Native
                : LoanTypes.CollateralType.ERC20
        });

        loan.tokenAddress = tokenAddress;
        loan.status = LoanTypes.LoanStatus.Requested;
        loan.dueDate = block.timestamp + duration;
        loan.lastInterestUpdate = block.timestamp;

        _loans[loanId] = loan;

        emit LoanCreated(loanId, borrower);
    }

    function getLoan(uint256 loanId) external view returns (LoanTypes.Loan memory) {
        return _loans[loanId];
    }

    function getLoanStatus(uint256 loanId) external view returns (LoanTypes.LoanStatus) {
        return _loans[loanId].status;
    }

    function updateLoanStatus(uint256 loanId, LoanTypes.LoanStatus newStatus) external onlyCore {
        LoanTypes.Loan storage loan = _loans[loanId];
        LoanTypes.LoanStatus oldStatus = loan.status;
        loan.status = newStatus;
        emit LoanStatusUpdated(loanId, oldStatus, newStatus);
    }

    // ---------- Repayment / Interest ----------
    function accrueInterest(uint256 loanId) external onlyCore {
        LoanTypes.Loan storage loan = _loans[loanId];
        uint256 elapsed = block.timestamp - loan.lastInterestUpdate;
        if (elapsed > 0) {
            // interestRateBps is in basis points (e.g. 500 = 5%)
            uint256 interest = (loan.amount * loan.interestRateBps * elapsed)
                / (10000 * 365 days);
            loan.amount += interest;
            loan.lastInterestUpdate = block.timestamp;
        }
    }

    /// @notice Compact view of loan details (without guarantor count, that lives in LoanGuarantors)
    function getLoanDetails(uint256 loanId)
        external
        view
        returns (
            address borrower,
            LoanTypes.PaymentType paymentType,
            address tokenAddress,
            uint256 amount,
            uint256 interestRateBps,
            uint256 duration,
            uint256 dueDate,
            LoanTypes.LoanStatus status
        )
    {
        LoanTypes.Loan storage loan = _loans[loanId];
        return (
            loan.borrower,
            loan.profile.paymentType,
            loan.tokenAddress,
            loan.amount,
            loan.interestRateBps,
            loan.duration,
            loan.dueDate,
            loan.status
        );
    }

    function reduceLoanAmount(uint256 loanId, uint256 amount) external onlyCore {
        LoanTypes.Loan storage loan = _loans[loanId];
        require(amount <= loan.amount, "LoanCore: repayment exceeds loan");
        loan.amount -= amount;

        emit LoanRepaid(loanId, amount, msg.sender);
    }

    // ---------- KYC ----------
    function setKycStatus(address member, LoanTypes.KycStatus status) external onlyCore {
        _kyc[member] = status;
        emit KycUpdated(member, status);
    }

    function getKycStatus(address member) external view returns (LoanTypes.KycStatus) {
        return _kyc[member];
    }

    // ---------- Borrower Info ----------
    function getBorrower(uint256 loanId) external view returns (address) {
        return _loans[loanId].borrower;
    }
}
