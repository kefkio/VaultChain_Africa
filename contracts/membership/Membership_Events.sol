// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library MembershipEvents {
    event BiodataSubmitted(address indexed user, uint256 timestamp);
    event MemberApproved(address indexed user, uint256 shares, bool isGuarantor);
    event DepositMade(address indexed sender, address indexed member, uint256 amount);
    event WalletChangeRequested(address indexed user, address newWallet);
    event WalletChangeApproved(address indexed user, address newWallet, address approver);
    event ApproverAdded(address approver);
    event ApproverRemoved(address approver);
}
