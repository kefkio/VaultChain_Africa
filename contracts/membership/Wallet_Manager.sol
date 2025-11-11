// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IMembershipModule {
    function updateMemberWallet(address member, address newWallet) external;
    function isMember(address user) external view returns (bool);
}

contract WalletManager is AccessControl {
    using Address for address;

    bytes32 public constant APPROVER_ROLE = keccak256("APPROVER_ROLE");
    uint256 public constant WALLET_CHANGE_QUORUM = 3;

    IMembershipModule public membership;

    // -----------------------------
    // Wallet Change Request Struct
    // -----------------------------
    struct WalletChangeRequest {
        address member;
        address proposedWallet;
        uint256 approvals;
        mapping(address => bool) approversBy; // tracks which admins approved
        bool executed;
    }

    mapping(uint256 => WalletChangeRequest) private walletChangeRequests;
    uint256 private walletChangeRequestCount;

    // -----------------------------
    // Events
    // -----------------------------
    event WalletChangeRequested(uint256 requestId, address member, address proposedWallet);
    event WalletChangeApproved(uint256 requestId, address approver);
    event WalletChangeExecuted(uint256 requestId, address member, address newWallet);

    // -----------------------------
    // Constructor
    // -----------------------------
    constructor(address membershipContract, address[] memory initialApprovers, address admin) {
        require(membershipContract != address(0), "Invalid membership address");
        require(initialApprovers.length >= WALLET_CHANGE_QUORUM, "Not enough initial approvers");

        membership = IMembershipModule(membershipContract);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        for (uint256 i = 0; i < initialApprovers.length; i++) {
            _grantRole(APPROVER_ROLE, initialApprovers[i]);
        }
    }

    // -----------------------------
    // Member Requests a Wallet Change
    // -----------------------------
    function submitWalletChangeRequest(address proposedWallet) external returns (uint256) {
        require(membership.isMember(msg.sender), "Not a member");
        require(proposedWallet != address(0), "Invalid wallet");

        walletChangeRequestCount++;
        uint256 requestId = walletChangeRequestCount;

        WalletChangeRequest storage request = walletChangeRequests[requestId];
        request.member = msg.sender;
        request.proposedWallet = proposedWallet;
        request.approvals = 0;
        request.executed = false;

        emit WalletChangeRequested(requestId, msg.sender, proposedWallet);
        return requestId;
    }

    // -----------------------------
    // Admin Approves Wallet Change
    // -----------------------------
    function approveWalletChangeRequest(uint256 requestId) external onlyRole(APPROVER_ROLE) {
        WalletChangeRequest storage request = walletChangeRequests[requestId];
        require(!request.executed, "Request already executed");
        require(!request.approversBy[msg.sender], "Already approved");

        request.approversBy[msg.sender] = true;
        request.approvals++;

        emit WalletChangeApproved(requestId, msg.sender);

        if (request.approvals >= WALLET_CHANGE_QUORUM) {
            _executeWalletChange(requestId);
        }
    }

    // -----------------------------
    // Internal Execution
    // -----------------------------
    function _executeWalletChange(uint256 requestId) internal {
        WalletChangeRequest storage request = walletChangeRequests[requestId];
        require(!request.executed, "Request already executed");
        require(request.approvals >= WALLET_CHANGE_QUORUM, "Not enough approvals");

        membership.updateMemberWallet(request.member, request.proposedWallet);

        request.executed = true;

        emit WalletChangeExecuted(requestId, request.member, request.proposedWallet);
    }

    // -----------------------------
    // Optional: Cancel request before execution
    // -----------------------------
    function cancelWalletChangeRequest(uint256 requestId) external {
        WalletChangeRequest storage request = walletChangeRequests[requestId];
        require(msg.sender == request.member, "Not request owner");
        require(!request.executed, "Already executed");

        delete walletChangeRequests[requestId];
    }

    // -----------------------------
    // View Functions
    // -----------------------------
    function getWalletChangeRequest(uint256 requestId)
        external
        view
        returns (
            address member,
            address proposedWallet,
            uint256 approvals,
            bool executed
        )
    {
        WalletChangeRequest storage request = walletChangeRequests[requestId];
        return (request.member, request.proposedWallet, request.approvals, request.executed);
    }

    function hasApproved(uint256 requestId, address approver) external view returns (bool) {
        WalletChangeRequest storage request = walletChangeRequests[requestId];
        return request.approversBy[approver];
    }

    function totalRequests() external view returns (uint256) {
        return walletChangeRequestCount;
    }
}
