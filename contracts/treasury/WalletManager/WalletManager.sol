// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../core/interfaces/IMembershipModule.sol";
import "../../core/interfaces/IWalletFactory.sol";
import "../../core/interfaces/IFeeManager.sol";
import "../WalletManager/WalletEvents.sol";


contract WalletManager is AccessControl {
    using Address for address;

    bytes32 public constant APPROVER_ROLE = keccak256("APPROVER_ROLE");
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
    uint256 public constant WALLET_CHANGE_QUORUM = 3;

    IMembershipModule public membership;
    IWalletFactory public walletFactory;
    IFeeManager public feeManager;

    enum OverrideStatus { PENDING, APPROVED, REJECTED, EXECUTED }

    struct WalletLink {
        address externalWallet;
        bool active;
        uint256 linkedAt;
    }

    struct WalletChangeRequest {
        address member;
        address proposedWallet;
        uint256 approvals;
        mapping(address => bool) approversBy;
        bool executed;
    }

struct OverrideRequest {
    address internalWallet;
    address proposedExternalWallet;
    address requestedBy;            // Who initiated the override
    uint256 approvals;             // Number of approvers who approved
    mapping(address => bool) approvedBy; 
    bool executed;                 // Has override been executed?
    uint256 timestamp;             // When request was created
    OverrideStatus status;         // PENDING → APPROVED → EXECUTED/REJECTED
}


    mapping(address => WalletLink) public internalWallets;
    mapping(uint256 => WalletChangeRequest) private walletChangeRequests;
    mapping(uint256 => OverrideRequest) private overrideRequests;

    uint256 private walletChangeRequestCount;
    uint256 private overrideRequestCount;

    constructor(
        address membershipContract,
        address walletFactoryContract,
        address feeManagerContract,
        address[] memory approvers,
        address registrarAdmin
    ) {
        require(membershipContract != address(0), "Invalid membership address");
        require(walletFactoryContract != address(0), "Invalid factory address");
        require(feeManagerContract != address(0), "Invalid fee manager");
        require(approvers.length >= WALLET_CHANGE_QUORUM, "Insufficient approvers");

        membership = IMembershipModule(membershipContract);
        walletFactory = IWalletFactory(walletFactoryContract);
        feeManager = IFeeManager(feeManagerContract);

        _grantRole(DEFAULT_ADMIN_ROLE, registrarAdmin);
        _grantRole(REGISTRAR_ROLE, registrarAdmin);

        for (uint256 i = 0; i < approvers.length; ) {
    _grantRole(APPROVER_ROLE, approvers[i]);
    _grantRole(REGISTRAR_ROLE, approvers[i]);

    unchecked { i++; }
        }
    }

    // -----------------------------
    // Member-Initiated Wallet Change
    // -----------------------------
    function submitWalletChangeRequest(address proposedWallet) external returns (uint256) {
        require(membership.isMember(msg.sender), "Not a member");
        require(proposedWallet != address(0), "Invalid wallet");

        walletChangeRequestCount++;
        uint256 requestId = walletChangeRequestCount;

        WalletChangeRequest storage request = walletChangeRequests[requestId];
        request.member = msg.sender;
        request.proposedWallet = proposedWallet;

        emit WalletEvents.WalletChangeInitiated(requestId, msg.sender, proposedWallet);
        return requestId;
    }

    function approveWalletChangeRequest(uint256 requestId) external onlyRole(APPROVER_ROLE) {
        WalletChangeRequest storage request = walletChangeRequests[requestId];
        require(!request.executed, "Already executed");
        require(!request.approversBy[msg.sender], "Already approved");

        request.approversBy[msg.sender] = true;
        request.approvals++;

        emit WalletEvents.WalletChangeApprovalRecorded(requestId, msg.sender);

        if (request.approvals >= WALLET_CHANGE_QUORUM) {
            _executeWalletChange(requestId);
        }
    }

    function _executeWalletChange(uint256 requestId) internal {
        WalletChangeRequest storage request = walletChangeRequests[requestId];
        require(!request.executed, "Already executed");
        require(request.approvals >= WALLET_CHANGE_QUORUM, "Insufficient approvals");

        internalWallets[request.member] = WalletLink({
            externalWallet: request.proposedWallet,
            active: true,
            linkedAt: block.timestamp
        });

        membership.updateMemberWallet(request.member, request.proposedWallet);
        request.executed = true;

        emit WalletEvents.WalletChangeFinalized(requestId, request.member, request.proposedWallet);
    }

    // -----------------------------
    // Registrar Quorum Override
    // -----------------------------


function submitOverrideRequest(
    address internalWallet,
    address externalWallet
)
    external
    onlyRole(REGISTRAR_ROLE)
    returns (uint256)
{
    require(internalWallet != address(0), "Invalid internal wallet");
    require(externalWallet != address(0), "Invalid external wallet");

    uint256 requestId = ++overrideRequestCount;

    OverrideRequest storage request = overrideRequests[requestId];
    request.internalWallet = internalWallet;
    request.proposedExternalWallet = externalWallet;
    request.requestedBy = msg.sender;
    request.timestamp = block.timestamp;
    request.status = OverrideStatus.PENDING;
    request.executed = false;

    emit WalletEvents.OverrideRequested(
        requestId,
        internalWallet,
        externalWallet
    );

    return requestId;
}



    function _executeOverride(uint256 requestId) internal {
        OverrideRequest storage request = overrideRequests[requestId];
        require(!request.executed, "Already executed");
        require(request.approvals >= WALLET_CHANGE_QUORUM, "Insufficient approvals");

        internalWallets[request.internalWallet] = WalletLink({
            externalWallet: request.proposedExternalWallet,
            active: true,
            linkedAt: block.timestamp
        });

        membership.updateMemberWallet(request.internalWallet, request.proposedExternalWallet);
        request.executed = true;

        emit WalletEvents.WalletOverrideExecuted(msg.sender, request.internalWallet, request.proposedExternalWallet, "Quorum override");
    }

    function approveOverride(uint256 requestId) external onlyRole(APPROVER_ROLE) {
    OverrideRequest storage request = overrideRequests[requestId];
    require(!request.executed, "Already executed");
    require(!request.approvedBy[msg.sender], "Already approved");

    request.approvals++;
    request.approvedBy[msg.sender] = true;

    emit WalletEvents.OverrideApprovalRecorded(requestId, msg.sender);

    // Auto-execute if quorum is reached
    if (request.approvals >= WALLET_CHANGE_QUORUM) {
        _executeOverride(requestId);
    }
}

    // -----------------------------
    // View Functions
    // -----------------------------
    function getWalletChangeRequest(uint256 requestId)
        external
        view
        returns (address member, address proposedWallet, uint256 approvals, bool executed)
    {
        WalletChangeRequest storage request = walletChangeRequests[requestId];
        return (request.member, request.proposedWallet, request.approvals, request.executed);
    }

    function hasApproved(uint256 requestId, address approver) external view returns (bool) {
        return walletChangeRequests[requestId].approversBy[approver];
    }

    function getExternalWallet(address internalWallet) external view returns (address) {
        return internalWallets[internalWallet].externalWallet;
    }

    function isActive(address internalWallet) external view returns (bool) {
        return internalWallets[internalWallet].active;
    }

    function totalRequests() external view returns (uint256) {
        return walletChangeRequestCount;
    }

    function totalOverrideRequests() external view returns (uint256) {
        return overrideRequestCount;
    }
}