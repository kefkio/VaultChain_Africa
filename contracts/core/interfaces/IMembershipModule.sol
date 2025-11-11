// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../../membership/Membership_Types.sol";

interface IMembershipModule {
    // --- 👤 Admin & Approver roles ---
    function addApprover(address newApprover) external;
    function removeApprover(address approver) external;
    function walletChangeQuorum() external view returns (uint256);

    /// @notice Updates a member's wallet address (called by WalletManager)
    function updateMemberWallet(address member, address newWallet) external;

    // --- 📝 Member submission ---
    function submitBiodata(
        string memory firstName,
        string memory middleName,
        string memory lastName,
        uint256 dateOfBirth,
        uint256 nationalIdHash,
        string memory passportNumberHash,
        string memory idDocumentHash,
        string memory passportPhotoHash
    ) external;

    function approveMembership(address applicant, bool makeGuarantor) external;

    // --- 👤 Membership getters ---
    function isMember(address user) external view returns (bool);
    
    function isGuarantor(address user) external view returns (bool);
    function getMemberWallet(address user) external view returns (address);
    function getShares(address user) external view returns (uint256);
    function getTotalDeposits(address user) external view returns (uint256);

    // --- 🧾 Composite member view ---
    function getMember(address user) external view returns (MembershipTypes.Member memory);

}
