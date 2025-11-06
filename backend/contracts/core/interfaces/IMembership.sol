// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IMembership {
    // --- 🔍 Membership Status ---
    function isMember(address user) external view returns (bool);
    function isGuarantor(address user) external view returns (bool);

    // --- 📊 Member Data ---
    function getShares(address user) external view returns (uint256);
    function getTotalDeposits(address user) external view returns (uint256);
    function getMemberWallet(address user) external view returns (address);

    // --- 📝 Application Access ---
    function getApplication(address applicant) external view returns (
        string memory name,
        uint256 nationalId,
        string memory passportNumber,
        string memory phone,
        string memory email,
        string memory nextOfKinName,
        string memory nextOfKinPhone,
        string memory nextOfKinEmail,
        string memory nextOfKinIdNumber,
        address wallet,
        bool isPending,
        uint256 appliedAt
    );

    // --- 🧾 Member Access ---
    function getMember(address user) external view returns (
        string memory name,
        uint256 nationalId,
        string memory passportNumber,
        string memory phone,
        string memory email,
        string memory nextOfKinName,
        string memory nextOfKinPhone,
        string memory nextOfKinEmail,
        string memory nextOfKinIdNumber,
        address wallet,
        uint256 registeredAt,
        bool isActive,
        bool isGuarantor,
        uint256 shares
    );
}
