// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../core/interfaces/IMembershipModule.sol";
import "./LoanCore.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LoanLogicFixed is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // -----------------------------
    // Modules
    // -----------------------------
    LoanCore public loanCore;
    IMembershipModule public membership;

    // -----------------------------
    // Roles
    // -----------------------------
    address public admin;
    address public loanLogic; // Only callable address

    // -----------------------------
    // Pool balances
    // -----------------------------
    mapping(address => uint256) public poolBalancesEther;
    mapping(address => mapping(address => uint256)) public poolBalancesToken;

    // -----------------------------
    // Events
    // -----------------------------
    event LoanDisbursed(uint256 indexed loanId, uint256 amount, address indexed borrower);
    event LoanRepaid(uint256 indexed loanId, uint256 amount, address indexed payer);
    event Withdrawn(address indexed user, uint256 amount);
    event WithdrawnToken(address indexed user, address indexed token, uint256 amount);

    // -----------------------------
    // Constructor
    // -----------------------------
    constructor(address _loanCore, address _membership, address _admin) {
        require(_loanCore != address(0), "Invalid LoanCore");
        require(_membership != address(0), "Invalid Membership");
        require(_admin != address(0), "Invalid admin");

        loanCore = LoanCore(_loanCore);
        membership = IMembershipModule(_membership);
        admin = _admin;
    }

    function setLoanLogic(address _loanLogic) external {
        require(loanLogic == address(0), "LoanLogic already set");
        loanLogic = _loanLogic;
    }

    modifier onlyLoanLogic() {
        require(msg.sender == loanLogic, "Only LoanLogic allowed");
        _;
    }

    // -----------------------------
    // KYC Operations
    // -----------------------------
    mapping(address => LoanCore.KycStatus) public kycStatus;
    mapping(address => bool) public registeredMembers;

    function updateKyc(address member, LoanCore.KycStatus status) external {
        require(msg.sender == admin, "Only admin can update KYC");
        require(registeredMembers[member], "Member not registered");
        kycStatus[member] = status;
    }

    function registerMemberFor(address member) external {
        registeredMembers[member] = true;
        kycStatus[member] = LoanCore.KycStatus.Pending;
    }

    function getKycStatus(address member) external view returns (LoanCore.KycStatus) {
        return kycStatus[member];
    }

    function isRegistered(address member) external view returns (bool) {
        return registeredMembers[member];
    }

    // -----------------------------
    // Loan Operations
    // -----------------------------
    function createLoan(
        address borrower,
        LoanCore.PaymentType paymentType,
        address tokenAddress,
        uint256 amount,
        uint256 duration,
        address[] memory guarantors
    ) external onlyLoanLogic returns (uint256) {
        return loanCore.createLoan(borrower, paymentType, tokenAddress, amount, duration, guarantors);
    }

    function reduceLoanAmount(uint256 loanId, uint256 amount) external onlyLoanLogic {
        loanCore.reduceLoanAmount(loanId, amount);
    }

    function updateLoanStatus(uint256 loanId, LoanCore.LoanStatus newStatus) external onlyLoanLogic {
        loanCore.updateLoanStatus(loanId, newStatus);
    }

    function requestLoan(
        uint256 amount,
        LoanCore.PaymentType paymentType,
        address tokenAddress,
        uint256 guarantorCount,
        uint256 duration,
        address[] memory guarantors
    ) external returns (uint256) {
        require(registeredMembers[msg.sender], "Member not registered");
        require(kycStatus[msg.sender] == LoanCore.KycStatus.Verified, "KYC not verified");
        return loanCore.createLoan(msg.sender, paymentType, tokenAddress, amount, duration, guarantors);
    }

    function approveLoan(uint256 loanId) external {
        LoanCore.Loan memory loan = loanCore.getLoan(loanId);
        require(loan.status == LoanCore.LoanStatus.Requested, "Loan not request stage");
        loanCore.updateLoanStatus(loanId, LoanCore.LoanStatus.Approved);
    }

    function disburseLoan(uint256 loanId) external payable nonReentrant {
        LoanCore.Loan memory loan = loanCore.getLoan(loanId);
        require(loan.status == LoanCore.LoanStatus.Approved, "Loan not approved");

        loanCore.updateLoanStatus(loanId, LoanCore.LoanStatus.Disbursed);

        if (loan.paymentType == LoanCore.PaymentType.Native) {
            if (msg.value > 0) {
                require(msg.value == loan.loan_amount, "Incorrect ETH sent for disbursement");
                poolBalancesEther[loan.borrower] += msg.value;
            } else {
                require(address(this).balance >= loan.loan_amount, "Insufficient ETH");
                poolBalancesEther[loan.borrower] += loan.loan_amount;
            }
        } else if (loan.paymentType == LoanCore.PaymentType.Token) {
            require(loan.tokenAddress != address(0), "Invalid token");
            IERC20(loan.tokenAddress).safeTransferFrom(msg.sender, address(this), loan.loan_amount);
            poolBalancesToken[loan.tokenAddress][loan.borrower] += loan.loan_amount;
        }

        emit LoanDisbursed(loanId, loan.loan_amount, loan.borrower);
    }

    function repayLoan(uint256 loanId, uint256 amount) external payable nonReentrant {
        require(amount > 0, "Invalid amount");
        LoanCore.Loan memory loan = loanCore.getLoan(loanId);
        require(loan.status == LoanCore.LoanStatus.Disbursed, "Loan not active");

        uint256 previousBalance = loan.loan_amount;
        uint256 repayAmount = amount;
        uint256 excess = 0;

        if (amount > previousBalance) {
            excess = amount - previousBalance;
            repayAmount = previousBalance;
        }

        if (loan.paymentType == LoanCore.PaymentType.Native) {
            require(msg.value == amount, "Incorrect ETH sent");
        } else if (loan.paymentType == LoanCore.PaymentType.Token) {
            IERC20(loan.tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        } else {
            revert("Unsupported payment type");
        }

        if (repayAmount > 0) {
            loanCore.reduceLoanAmount(loanId, repayAmount);
        }

        if (repayAmount == previousBalance) {
            loanCore.updateLoanStatus(loanId, LoanCore.LoanStatus.FullyRepaid);
        } else {
            loanCore.updateLoanStatus(loanId, LoanCore.LoanStatus.PartiallyRepaid);
        }

        if (loan.paymentType == LoanCore.PaymentType.Native) {
            poolBalancesEther[loan.borrower] += amount;
        } else {
            poolBalancesToken[loan.tokenAddress][loan.borrower] += amount;
        }

        emit LoanRepaid(loanId, amount, msg.sender);
    }

    function markDefault(uint256 loanId) external {
        LoanCore.Loan memory loan = loanCore.getLoan(loanId);
        require(block.timestamp > loan.dueDate, "Loan not overdue");
        require(loan.status != LoanCore.LoanStatus.FullyRepaid, "Loan already repaid");
        loanCore.updateLoanStatus(loanId, LoanCore.LoanStatus.Defaulted);
    }

    // -----------------------------
    // Withdrawals
    // -----------------------------
    function withdrawEther(uint256 amount) external nonReentrant {
        require(poolBalancesEther[msg.sender] >= amount, "Insufficient balance");
        poolBalancesEther[msg.sender] -= amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH withdrawal failed");
        emit Withdrawn(msg.sender, amount);
    }

    function withdrawToken(address token, uint256 amount) external nonReentrant {
        require(poolBalancesToken[token][msg.sender] >= amount, "Insufficient token balance");
        poolBalancesToken[token][msg.sender] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit WithdrawnToken(msg.sender, token, amount);
    }

    // -----------------------------
    // View
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
        LoanCore.Loan memory loan = loanCore.getLoan(loanId);
        return (
            loan.borrower,
            loan.paymentType,
            loan.tokenAddress,
            loan.guarantors.length,
            loan.loan_amount,
            loan.interestRate,
            loan.duration,
            loan.dueDate,
            loan.status
        );
    }

    function getActiveLoanId(address borrower) external view returns (uint256) {
        return loanCore.activeLoan(borrower);
    }

    // Allow contract to receive ETH

    receive() external payable {}
}
