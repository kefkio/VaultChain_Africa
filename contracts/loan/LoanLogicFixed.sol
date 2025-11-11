// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
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
    // Roles (used in LoanManager)
    // -----------------------------
    address public admin;

    // -----------------------------
    // Pool balances (per borrower)
    // -----------------------------
    mapping(address => uint256) public poolBalancesEther;
    mapping(address => mapping(address => uint256)) public poolBalancesToken; // token => (user => amount)

    // -----------------------------
    // Events
    // -----------------------------
    event LoanDisbursed(uint256 indexed loanId, uint256 amount, address indexed borrower);
    event LoanRepaid(uint256 indexed loanId, uint256 amount, address indexed payer);
    event Withdrawn(address indexed user, uint256 amount);
    event WithdrawnToken(address indexed user, address indexed token, uint256 amount);

    // -----------------------------
    // Initialization
    // -----------------------------
    constructor(address _loanCore, address _membership, address _admin) {
        require(_loanCore != address(0), "Invalid LoanCore");
        require(_membership != address(0), "Invalid Membership");
        require(_admin != address(0), "Invalid admin");

        loanCore = LoanCore(_loanCore);
        membership = IMembershipModule(_membership);
        admin = _admin;
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

    function getKycStatus(address member) external view returns (LoanCore.KycStatus) {
        return kycStatus[member];
    }

    function isRegistered(address member) external view returns (bool) {
        return registeredMembers[member];
    }

    function registerMemberFor(address member) external {
        registeredMembers[member] = true;
        kycStatus[member] = LoanCore.KycStatus.Pending;
    }

    // -----------------------------
    // Loan Operations
    // -----------------------------
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

    /**
     * Disburse loan into the borrower's pool balance.
     *
     * For native (ETH): operator may either send msg.value == loan.loan_amount with the call,
     * or the contract must already hold sufficient balance (from previous deposits/funding).
     *
     * For tokens: operator must approve and call this function; tokens are pulled via safeTransferFrom.
     */
    function disburseLoan(uint256 loanId) external payable nonReentrant {
        LoanCore.Loan memory loan = loanCore.getLoan(loanId);
        require(loan.status == LoanCore.LoanStatus.Approved, "Loan not approved");

        // Effects: mark as disbursed first
        loanCore.updateLoanStatus(loanId, LoanCore.LoanStatus.Disbursed);

        // Interaction: move funds into internal pool accounting
        if (loan.paymentType == LoanCore.PaymentType.Native) {
            // If operator sent funds with this tx, require exact amount
            if (msg.value > 0) {
                require(msg.value == loan.loan_amount, "Incorrect ETH sent for disbursement");
                poolBalancesEther[loan.borrower] += msg.value;
            } else {
                // Otherwise, ensure contract already has enough ETH to cover disbursement
                require(address(this).balance >= loan.loan_amount, "Contract has insufficient ETH for disbursement");
                poolBalancesEther[loan.borrower] += loan.loan_amount;
            }
        } else if (loan.paymentType == LoanCore.PaymentType.Token) {
            // Pull ERC20 tokens from caller into contract and credit pool
            require(loan.tokenAddress != address(0), "Invalid token address");
            IERC20(loan.tokenAddress).safeTransferFrom(msg.sender, address(this), loan.loan_amount);
            poolBalancesToken[loan.tokenAddress][loan.borrower] += loan.loan_amount;
        }

        emit LoanDisbursed(loanId, loan.loan_amount, loan.borrower);
    }

    /**
     * Repay loan: payment (native or ERC20) is accepted into contract and credited to the borrower's pool.
     * Excess over outstanding loan balance is credited to the borrower's pool as well.
     */
    function repayLoan(uint256 loanId, uint256 amount) external payable nonReentrant {
        require(amount > 0, "Invalid amount");
        LoanCore.Loan memory loan = loanCore.getLoan(loanId);
        require(loan.status == LoanCore.LoanStatus.Disbursed, "Loan not active");

        uint256 previousBalance = loan.loan_amount; // outstanding before repay
        uint256 repayAmount = amount;
        uint256 excess = 0;

        if (amount > previousBalance) {
            excess = amount - previousBalance;
            repayAmount = previousBalance;
        }

        // Accept funds (native or ERC20) into contract first (Interactions limited to transfers from payer)
        if (loan.paymentType == LoanCore.PaymentType.Native) {
            require(msg.value == amount, "Incorrect ETH sent");
            // ETH is already held by contract via payable call
            // credit pool: we'll credit the entire 'amount' (repay + possible excess) below
        } else if (loan.paymentType == LoanCore.PaymentType.Token) {
            // pull tokens from payer; amount includes any excess
            IERC20(loan.tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        } else {
            revert("Unsupported payment type");
        }

        // Effects: reduce loan principal first
        if (repayAmount > 0) {
            loanCore.reduceLoanAmount(loanId, repayAmount);
        }

        // If fully repaid, update status and clear active loan entry
        if (repayAmount == previousBalance) {
            loanCore.updateLoanStatus(loanId, LoanCore.LoanStatus.FullyRepaid);
        } else {
            // If partially repaid, leave as Disbursed or set to PartiallyRepaid if you prefer:
            loanCore.updateLoanStatus(loanId, LoanCore.LoanStatus.PartiallyRepaid);
        }

        // Interactions: credit entire received amount (repay + excess) to borrower's pool
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
    // Withdrawals (from user's pool balances)
    // -----------------------------
    function withdrawEther(uint256 amount) external nonReentrant {
        require(poolBalancesEther[msg.sender] >= amount, "Insufficient pool balance");
        poolBalancesEther[msg.sender] -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Ether withdrawal failed");

        emit Withdrawn(msg.sender, amount);
    }

    function withdrawToken(address token, uint256 amount) external nonReentrant {
        require(poolBalancesToken[token][msg.sender] >= amount, "Insufficient token pool balance");
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

    // Allow contract to receive ETH (e.g. to fund disbursements)
    receive() external payable {}
}
