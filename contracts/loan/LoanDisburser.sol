
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./LoanCore.sol";
import "../core/interfaces/IMembershipModule.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract LoanDisburser is ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;

    LoanCore public loanCore;
    IMembershipModule public membership;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    event LoanDisbursed(uint256 loanId);
    event LoanRepaid(uint256 loanId, uint256 amount);
    event LoanDefaulted(uint256 loanId);

    constructor(address loanCoreAddress, address membershipContract) {
        loanCore = LoanCore(loanCoreAddress);
        membership = IMembershipModule(membershipContract);
    }

    function disburseLoan(uint256 loanId) external onlyRole(OPERATOR_ROLE) {
    LoanCore.Loan memory loan = loanCore.getLoan(loanId);
    require(loan.status == LoanCore.LoanStatus.Approved, "Loan not approved");

    address wallet = membership.getMemberWallet(loan.borrower);
    require(wallet != address(0), "Wallet mismatch");

    if (loan.paymentType == LoanCore.PaymentType.Native) {
        (bool success, ) = wallet.call{value: loan.loan_amount}("");
        require(success, "Native transfer failed");
    } else if (loan.paymentType == LoanCore.PaymentType.Token) {
        IERC20(loan.tokenAddress).safeTransferFrom(msg.sender, wallet, loan.loan_amount);
    }

    // Use LoanCore function to persist status update
    loanCore.updateLoanStatus(loanId, LoanCore.LoanStatus.Disbursed);

    emit LoanDisbursed(loanId);
}


    function repayLoan(uint256 loanId, uint256 amount) external payable nonReentrant {
    LoanCore.Loan memory loan = loanCore.getLoan(loanId);

    require(loan.status == LoanCore.LoanStatus.Disbursed, "Loan not active");
    require(amount > 0, "Invalid amount");

    if (loan.paymentType == LoanCore.PaymentType.Native) {
        require(msg.value == amount, "Incorrect repayment amount");
    } else if (loan.paymentType == LoanCore.PaymentType.Token) {
        IERC20(loan.tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
    }

    // Persist repayment
    loanCore.reduceLoanAmount(loanId, amount);

    // Update status if needed
    if (loan.loan_amount == amount) { // full repayment
        loanCore.updateLoanStatus(loanId, LoanCore.LoanStatus.FullyRepaid);
    } else {
        loanCore.updateLoanStatus(loanId, LoanCore.LoanStatus.PartiallyRepaid);
    }

    emit LoanRepaid(loanId, amount);
}


function markDefault(uint256 loanId) external onlyRole(OPERATOR_ROLE) {
    LoanCore.Loan memory loan = loanCore.getLoan(loanId);
    require(block.timestamp > loan.dueDate, "Loan not overdue");
    require(loan.status != LoanCore.LoanStatus.FullyRepaid, "Loan already repaid");
    require(loan.status != LoanCore.LoanStatus.Defaulted, "Loan already defaulted");

    // Persist the status change via LoanCore's API
    loanCore.updateLoanStatus(loanId, LoanCore.LoanStatus.Defaulted);

    emit LoanDefaulted(loanId);
}


}
