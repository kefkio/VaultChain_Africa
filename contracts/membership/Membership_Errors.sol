// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library MembershipErrors {
    error NotAuthorized();
    error NotAnApprover();
    error AlreadySubmitted();
    error InvalidData();
    error NoPendingApplication();
    error NotAMember();
    error InvalidWallet();
    error NoWalletChangeRequest();
    error AlreadyVoted();
    error CannotRemoveAdmin();
}
