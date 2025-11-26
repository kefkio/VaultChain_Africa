// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @notice Common events for loan flows and wallet/registrar flows.
/// @dev Ensure `LoanStatus` enum is declared in the project (either in this file or imported).
library LoanEvents {
    // Wallet change flow
    event WalletChangeRequested(uint256 indexed requestId, address indexed member, address proposedWallet);
    event WalletChangeApproved(uint256 indexed requestId, address indexed approver);
    event WalletChangeExecuted(uint256 indexed requestId, address indexed member, address newWallet);
    event WalletChangeInitiated(uint256 indexed requestId, address indexed member, address proposedWallet);
    event WalletChangeApprovalRecorded(uint256 indexed requestId, address indexed approver);
    event WalletChangeFinalized(uint256 indexed requestId, address indexed member, address proposedWallet);

    // Registrar override flow
    event OverrideRequested(uint256 indexed requestId, address indexed internalWallet, address indexed externalWallet);
    event OverrideApprovalRecorded(uint256 indexed requestId, address indexed approver);
    event WalletOverrideExecuted(address indexed registrar, address indexed internalWallet, address indexed externalWallet, string reason);

    // Loan flow events (unique, de-duplicated)
    event LoanRequested(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event LoanDisbursed(uint256 indexed loanId, uint256 amount, address indexed borrower);
    event LoanAmountReduced(uint256 indexed loanId, uint256 newAmount);
    event GuarantorAdded(uint256 indexed loanId, address indexed guarantor);
    event GuarantorRemoved(uint256 indexed loanId, address indexed guarantor);
    event InterestAccrued(uint256 indexed loanId, uint256 interestAmount);
    event LoanRepaid(uint256 indexed loanId, uint256 amount, address indexed payer);
    event LoanStatusUpdated(uint256 indexed loanId, /*LoanStatus*/ uint8 newStatus); // use LoanStatus if accessible
    event LoanCreated(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event BorrowerCollateralRecorded(uint256 indexed loanId, uint256 amount, address token);
    event GuarantorRecorded(uint256 indexed loanId, address guarantor, uint256 amount, address token);
    event LoanDefaulted(uint256 indexed loanId,address indexed borrower);
    event LoanFullyRepaid(uint256 indexed loanId, address indexed borrower);
    event KycUpdated(address indexed member, uint8 status); // use LoanCore.KycStatus if accessible
    

    // Withdrawals
    event Withdrawn(address indexed user, uint256 amount);
    event WithdrawnToken(address indexed user, address indexed token, uint256 amount);
}
