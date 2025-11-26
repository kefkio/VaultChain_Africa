// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library WalletEvents {

    // Wallet change flow
    event WalletChangeRequested(uint256 requestId, address member, address proposedWallet);
    event WalletChangeApproved(uint256 requestId, address approver);
    event WalletChangeExecuted(uint256 requestId, address member, address newWallet);
    event WalletChangeInitiated(uint256 requestId, address member, address proposedWallet);
    event WalletChangeApprovalRecorded(uint256 requestId, address approver);
    event WalletChangeFinalized(uint256 requestId, address member, address proposedWallet);

    // Registrar override flow
    event OverrideRequested(uint256 requestId, address internalWallet, address externalWallet);
    event OverrideApprovalRecorded(uint256 requestId, address approver);
    event WalletOverrideExecuted(address registrar, address internalWallet, address externalWallet, string reason);

}
