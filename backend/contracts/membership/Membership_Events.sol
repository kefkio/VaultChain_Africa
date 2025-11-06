// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

library MembershipEvents {
    event MemberApplied(address indexed applicant, uint256 appliedAt);
    event MemberApproved(address indexed member, uint256 shares, bool isGuarantor);
    event DepositMade(address indexed from, address indexed to, uint256 amount);
    event WalletChangeRequested(address indexed member, address newWallet);
    event WalletChangeApproved(address indexed member, address newWallet, address approver);
    event ApproverAdded(address indexed approver);
    event ApproverRemoved(address indexed approver);

    event BiodataSubmitted(address indexed member, uint256 timestamp);
    
}