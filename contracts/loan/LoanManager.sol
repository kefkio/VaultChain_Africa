// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../core/interfaces/IMembershipModule.sol";
import "./LoanCore.sol";
import "./LoanLogicFixed.sol";





contract LoanManager is AccessControl, Initializable, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // -----------------------------
    // Modules
    // -----------------------------
    LoanCore public loanStorage;
    LoanLogicFixed public loanLogic;
    IMembershipModule public membership;

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
        require(_loanStorage != address(0), "Invalid LoanCore");
        require(_loanLogic != address(0), "Invalid LoanLogic");
        require(_membership != address(0), "Invalid Membership");

        loanStorage = LoanCore(_loanStorage);
        loanLogic = LoanLogicFixed(payable(_loanLogic));
        membership = IMembershipModule(_membership);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        for (uint i = 0; i < operators.length; i++) {
            _grantRole(OPERATOR_ROLE, operators[i]);
        }
    }

    // -----------------------------
    // Member & KYC Operations
    // -----------------------------
    function updateKyc(address member, LoanCore.KycStatus status)
        external
        onlyRole(OPERATOR_ROLE)
    {
        loanLogic.updateKyc(member, status);
    }

    // -----------------------------
    // Loan Lifecycle Operations
    // -----------------------------
    function requestLoan(
        uint256 amount,
        LoanCore.PaymentType paymentType,
        address tokenAddress,
        uint256 guarantorCount,
        uint256 duration,
        address[] memory guarantors
    ) external returns (uint256) {
        return loanLogic.requestLoan(
            amount,
            paymentType,
            tokenAddress,
            guarantorCount,
            duration,
            guarantors
        );
    }

    function createLoan(
        address borrower,
        LoanCore.PaymentType paymentType,
        address tokenAddress,
        uint256 amount,
        uint256 duration,
        address[] memory guarantors
    ) external nonReentrant onlyRole(OPERATOR_ROLE) returns (uint256) {
        require(borrower != address(0), "Invalid borrower");

        // Delegate loan creation to loanLogic
        uint256 loanId = loanLogic.requestLoan(
            amount,
            paymentType,
            tokenAddress,
            guarantors.length,
            duration,
            guarantors
        );

        return loanId;
    }

    function approveLoan(uint256 loanId) external onlyRole(OPERATOR_ROLE) {
        loanLogic.approveLoan(loanId);
    }

    function disburseLoan(uint256 loanId) external onlyRole(OPERATOR_ROLE) {
        loanLogic.disburseLoan(loanId);
    }

    function repayLoan(uint256 loanId, uint256 amount) external payable {
        loanLogic.repayLoan(loanId, amount);
    }

    function markDefault(uint256 loanId) external onlyRole(OPERATOR_ROLE) {
        loanLogic.markDefault(loanId);
    }

    // -----------------------------
    // View Functions
    // -----------------------------
    function getLoanDetails(uint256 loanId)
        external
        view
        returns (
            address borrower,
            LoanCore.PaymentType paymentType,
            address tokenAddress,
            uint256 guarantorCount,
            uint256 amount,
            uint256 interestRate,
            uint256 duration,
            uint256 dueDate,
            LoanCore.LoanStatus status
        )
    {
        return loanLogic.getLoanDetails(loanId);
    }

    function getKycStatus(address member)
        external
        view
        returns (LoanCore.KycStatus)
    {
        return loanLogic.getKycStatus(member);
    }

    function isRegistered(address member) external view returns (bool) {
        return loanLogic.isRegistered(member);
    }

    function getActiveLoanId(address borrower)
        external
        view
        returns (uint256)
    {
        return loanLogic.getActiveLoanId(borrower);
    }
}
