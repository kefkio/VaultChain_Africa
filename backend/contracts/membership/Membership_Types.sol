// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

library MembershipTypes {

    /// @notice Struct to hold a member's submission data before approval
    struct MemberSubmission {
        string name;                  // Member full name
        uint256 nationalIdHash;       // keccak256 hash of National ID
        string passportNumberHash;    // keccak256 hash of Passport Number
        string idDocumentHash;        // Hash of uploaded ID/passport file
        string passportPhotoHash;     // Hash of uploaded passport photo
        bool submitted;               // True if submission completed
        uint256 submittedAt;          // Timestamp of submission
    }

    /// @notice Struct to represent an approved member
    struct Member {
        string name;                  // Member full name
        uint256 nationalId;           // Hashed National ID
        string passportNumber;        // Hashed Passport Number
        address wallet;               // Member wallet address
        uint256 registeredAt;         // Timestamp when approved
        bool isActive;                // Active status
        bool isGuarantor;             // True if member is guarantor
        uint256 shares;               // Membership shares
    }

    /// @notice Optional: extend with more metadata off-chain
    // struct AdditionalInfo { ... } 
}
