// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

library MembershipErrors {
    error AlreadyApplied();
    error AlreadyMember();
    error InvalidWallet();
    error DuplicateNationalId();
    error DuplicatePassport();
    error DuplicatePhone();
    error DuplicateEmail();
    error NoPendingApplication();
    error NotAMember();
    error NotAnApprover();
    error AlreadyVoted();
    error NoWalletChangeRequest();
    error CannotRemoveAdmin();
    
    error AlreadySubmitted();        // When member tries to submit biodata twice
    
    error InvalidData();             // When required fields or document hashes are empty

}