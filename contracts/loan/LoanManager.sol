// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../core/interfaces/IMembershipModule.sol";
import "./LoanCore.sol";
import "./LoanLogic.sol";
import "./LoanTypes.sol";

/// @title LoanManager
/// @notice High-level manager for loan operations, delegating to LoanLogic and LoanCore
contract LoanManager is AccessControl, Initializable, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // -----------------------------
    // Modules
    // -----------------------------
    LoanCore public loanStorage;
    LoanLogic public loanLogic;
    IMembershipModule public membership;

    mapping(address => uint256) private _activeLoanIds;

    // -----------------------------
    // Initialization
    // -----------------------------
    function initialize(
        address _loanStorage,
        address _loanLogic,
        address _membership,
        address admin,
        address[] memory operators
    ) external initializer {
        require(_loanStorage != address(0), "LoanManager: invalid LoanCore");
        require(_loanLogic != address(0), "LoanManager: invalid LoanLogic");
        require(_membership != address(0), "LoanManager: invalid Membership");
        require(admin != address(0), "LoanManager: invalid admin");

        loanStorage = LoanCore(_loanStorage);
        loanLogic   = LoanLogic(_loanLogic);
        membership  = IMembershipModule(_membership);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        for (uint256 i = 0; i < operators.length; i++) {
            _grantRole(OPERATOR_ROLE, operators[i]);
        }
    }

    // -----------------------------
    // Admin Helpers
    // -----------------------------
    function addOperator(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(OPERATOR_ROLE, account);
    }

    function removeOperator(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(OPERATOR_ROLE, account);
    }

    function isOperator(address account) external view returns (bool) {
        return hasRole(OPERATOR_ROLE, account);
    }

    // -----------------------------
    // KYC Operations
    // -----------------------------
    function updateKyc(address member, LoanTypes.KycStatus status)
        external
        onlyRole(OPERATOR_ROLE)
    {
        loanLogic.updateKyc(member, status);
    }

    // -----------------------------
    // Borrower Operations
    // -----------------------------
    function requestLoan(
        uint256 amount,
        uint256 duration,
        uint256 interestRate,
        uint256 borrowerCollateralAmount,
        address borrowerCollateralToken,
        LoanTypes.PaymentType paymentType,
        address tokenAddress,
        address[] calldata guarantors
    ) external nonReentrant returns (uint256) {
        require(membership.isMember(msg.sender), "LoanManager: not active member");

        return loanLogic.createLoan(
            msg.sender,
            amount,
            duration,
            interestRate,
            borrowerCollateralAmount,
            borrowerCollateralToken,
            paymentType,
            tokenAddress,
            guarantors
        );
    }

function repayLoan(uint256 loanId, uint256 amount, address _payer) external payable nonReentrant {
    // handle ETH repayment logic here
}

    // -----------------------------
    // Operator-assisted Loan Operations
    // -----------------------------
    function createLoanForBorrower(
        address borrower,
        uint256 amount,
        uint256 duration,
        uint256 interestRate,
        uint256 borrowerCollateralAmount,
        address borrowerCollateralToken,
        LoanTypes.PaymentType paymentType,
        address tokenAddress,
        address[] calldata guarantors
    ) external nonReentrant onlyRole(OPERATOR_ROLE) returns (uint256) {
        return loanLogic.createLoan(
            borrower,
            amount,
            duration,
            interestRate,
            borrowerCollateralAmount,
            borrowerCollateralToken,
            paymentType,
            tokenAddress,
            guarantors
        );
    }

    function approveLoan(uint256 loanId) external onlyRole(OPERATOR_ROLE) {
        loanLogic.approveLoan(loanId);
    }

    function disburseLoan(uint256 loanId) external onlyRole(OPERATOR_ROLE) {
        loanLogic.disburseLoan(loanId);
    }

    function markDefault(uint256 loanId) external onlyRole(OPERATOR_ROLE) {
        loanLogic.markDefault(loanId);
    }

    function acceptGuarantorRole(uint256 loanId) external {
        loanLogic.acceptGuarantorRole(loanId);
    }

    // -----------------------------
    // Views
    // -----------------------------
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
        return loanLogic.getLoanDetails(loanId); // <-- call passthrough in LoanLogic
    }

    function getKycStatus(address member) external view returns (LoanTypes.KycStatus) {
        return loanLogic.getKycStatus(member);
    }

    function isRegistered(address member) external view returns (bool) {
        return membership.isMember(member);
    }

    // -----------------------------
    // Active loan tracking (explicit)
    // -----------------------------
    function setActiveLoan(address borrower, uint256 loanId) external onlyRole(OPERATOR_ROLE) {
        _activeLoanIds[borrower] = loanId;
    }

    function clearActiveLoan(address borrower) external onlyRole(OPERATOR_ROLE) {
        _activeLoanIds[borrower] = 0;
    }

    function getActiveLoanId(address borrower) external view returns (uint256) {
        return _activeLoanIds[borrower];
    }
  
    
}