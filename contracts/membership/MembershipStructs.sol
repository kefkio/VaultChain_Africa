// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

library MembershipStructs {
    struct MemberSubmission {
        string firstName;
        string middleName;
        string lastName;
        uint256 dateOfBirth; 
        uint256 nationalIdHash;
        string passportNumberHash;
        string idDocumentHash;
        string passportPhotoHash;
        bool submitted;
        uint256 submittedAt;
    }
}
