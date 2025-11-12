// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./Membership_Events.sol";
import "./Membership_Errors.sol";
import "./Membership_Shares.sol";
import "./Membership_Types.sol";
import "./MembershipStructs.sol";

contract MembershipModule {
    using MembershipShares for uint8;
    using MembershipTypes for MembershipTypes.Member;

    // --- 👤 ADMIN & APPROVER ROLES ---
    address public admin;
    uint256 public walletChangeQuorum = 2;
    mapping(address => bool) public approvers;

    // --- 🗂 MEMBER DATA STORAGE ---
    mapping(address => MembershipStructs.MemberSubmission) public memberSubmissions;
    mapping(address => MembershipTypes.Member) public members;
    mapping(address => uint256) public totalDeposits;

    // --- 🔐 WALLET CHANGE WORKFLOW ---
    uint256 public walletChangeRequestCount;
    mapping(address => uint256) public walletChangeRequestIds;
    mapping(address => address) public pendingWalletChanges;
    mapping(address => mapping(address => bool)) public walletChangeVotes;
    mapping(address => uint256) public walletChangeVoteCount;

    // --- 🔐 MODIFIERS ---
    modifier onlyAdmin() {
        if (msg.sender != admin) revert MembershipErrors.NotAuthorized();
        _;
    }

    modifier onlyApprover() {
        if (!approvers[msg.sender]) revert MembershipErrors.NotAnApprover();
        _;
    }

    // --- ⚡ CONSTRUCTOR ---
    constructor() {
        admin = msg.sender;
        approvers[msg.sender] = true;
    }

    // --- 📝 MEMBER BIODATA SUBMISSION ---
    function submitBiodata(
        string memory firstName,
        string memory middleName,
        string memory lastName,
        uint256 dateOfBirth,
        uint256 nationalIdHash,
        string memory passportNumberHash,
        string memory idDocumentHash,
        string memory passportPhotoHash
    ) external {
        MembershipStructs.MemberSubmission storage sub = memberSubmissions[msg.sender];

        if (sub.submitted) revert MembershipErrors.AlreadySubmitted();
        if (bytes(firstName).length == 0 || bytes(middleName).length == 0 || bytes(lastName).length == 0)
            revert MembershipErrors.InvalidData();
        if (dateOfBirth == 0) revert MembershipErrors.InvalidData();
        if (_checkId(nationalIdHash, passportNumberHash)) revert MembershipErrors.InvalidData();
        if (bytes(idDocumentHash).length == 0 || bytes(passportPhotoHash).length == 0)
            revert MembershipErrors.InvalidData();

        sub.firstName = firstName;
        sub.middleName = middleName;
        sub.lastName = lastName;
        sub.dateOfBirth = dateOfBirth;
        sub.nationalIdHash = nationalIdHash;
        sub.passportNumberHash = passportNumberHash;
        sub.idDocumentHash = idDocumentHash;
        sub.passportPhotoHash = passportPhotoHash;
        sub.submitted = true;
        sub.submittedAt = block.timestamp;

        emit MembershipEvents.BiodataSubmitted(msg.sender, block.timestamp);
    }

    function _checkId(uint256 nationalIdHash, string memory passportNumberHash) internal pure returns (bool) {
        return nationalIdHash == 0 && bytes(passportNumberHash).length == 0;
    }

    // --- ✅ APPROVE MEMBERSHIP ---
    function approveMembership(address applicant, MembershipTypes.MemberType memberType, bool makeGuarantor) external onlyAdmin {
        MembershipStructs.MemberSubmission memory sub = memberSubmissions[applicant];
        if (!sub.submitted) revert MembershipErrors.NoPendingApplication();

        members[applicant] = MembershipTypes.Member({
            name: string(abi.encodePacked(sub.firstName, " ", sub.lastName)),
            nationalIdHash: sub.nationalIdHash,
            passportNumberHash: sub.passportNumberHash,
            phone: "",
            email: "",
            nextOfKinName: "",
            nextOfKinPhone: "",
            nextOfKinEmail: "",
            nextOfKinIdNumber: "",
            wallet: applicant,
            registeredAt: block.timestamp,
            isActive: true,
            isGuarantor: makeGuarantor,
            shares: MembershipShares.calculateSharesOnJoin(uint8(memberType)),
            memberType: memberType
        });

        emit MembershipEvents.MemberApproved(applicant, members[applicant].shares, makeGuarantor);
    }

    // --- 💰 DEPOSIT TRACKING ---
    function deposit(address member) external payable {
        if (!members[member].isActive) revert MembershipErrors.NotAMember();
        totalDeposits[member] += msg.value;
        emit MembershipEvents.DepositMade(msg.sender, member, msg.value);
    }

    // --- 🔐 WALLET CHANGE REQUEST ---
    function requestWalletChange(address newWallet) external {
        if (!members[msg.sender].isActive) revert MembershipErrors.NotAMember();
        if (newWallet == address(0)) revert MembershipErrors.InvalidWallet();

        walletChangeRequestCount++;
        walletChangeRequestIds[msg.sender] = walletChangeRequestCount;

        pendingWalletChanges[msg.sender] = newWallet;
        walletChangeVoteCount[msg.sender] = 0;

        emit MembershipEvents.WalletChangeRequested(walletChangeRequestCount, msg.sender, newWallet);
    }

    function approveWalletChange(address member) external onlyApprover {
        if (pendingWalletChanges[member] == address(0)) revert MembershipErrors.NoWalletChangeRequest();
        if (walletChangeVotes[member][msg.sender]) revert MembershipErrors.AlreadyVoted();

        walletChangeVotes[member][msg.sender] = true;
        walletChangeVoteCount[member]++;

        uint256 requestId = walletChangeRequestIds[member];
        emit MembershipEvents.WalletChangeApproved(requestId, msg.sender);

        if (walletChangeVoteCount[member] >= walletChangeQuorum) {
            members[member].wallet = pendingWalletChanges[member];
            delete pendingWalletChanges[member];
            delete walletChangeVoteCount[member];
            delete walletChangeRequestIds[member];
            emit MembershipEvents.WalletChangeExecuted(requestId, member, members[member].wallet);
        }
    }

    // --- 🛡️ ADMIN ROLE MANAGEMENT ---
    function addApprover(address newApprover) external onlyAdmin {
        if (newApprover == address(0)) revert MembershipErrors.InvalidWallet();
        approvers[newApprover] = true;
        emit MembershipEvents.ApproverAdded(newApprover);
    }

    function removeApprover(address approver) external onlyAdmin {
        if (approver == admin) revert MembershipErrors.CannotRemoveAdmin();
        approvers[approver] = false;
        emit MembershipEvents.ApproverRemoved(approver);
    }

    // --- 🔍 VIEW FUNCTIONS ---
    function getMemberSubmission(address user) external view returns (MembershipStructs.MemberSubmission memory) {
        return memberSubmissions[user];
    }

    function isMember(address user) external view returns (bool) {
        return members[user].isActive;
    }

    function isGuarantor(address user) external view returns (bool) {
        return members[user].isGuarantor;
    }

    function getShares(address user) external view returns (uint256) {
        return members[user].shares;
    }

    function getTotalDeposits(address user) external view returns (uint256) {
        return totalDeposits[user];
    }

    function getMemberWallet(address user) external view returns (address) {
        return members[user].wallet;
    }
}