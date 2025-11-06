// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./MembershipErrors.sol";
import "./MembershipEvents.sol";
import "./MembershipShares.sol";
import "./MembershipTypes.sol";

contract MembershipModule {
    using MembershipShares for uint256;
    using MembershipTypes for MembershipTypes.Member;

    // --- 👤 ADMIN & APPROVER ROLES ---
    address public admin;
    uint256 public walletChangeQuorum = 2;

    mapping(address => bool) public approvers;

    // --- 🗂 MEMBER DATA STORAGE ---
    struct MemberSubmission {
        string firstName;
        string middleName;
        string lastName;
        uint256 dateOfBirth; // UNIX timestamp
        uint256 nationalIdHash;         // keccak256 hash of National ID
        string passportNumberHash;      // keccak256 hash of Passport Number
        string idDocumentHash;          // hash of uploaded ID/passport file
        string passportPhotoHash;       // hash of uploaded passport photo
        bool submitted;
        uint256 submittedAt;
    }

    mapping(address => MemberSubmission) public memberSubmissions;
    mapping(address => MembershipTypes.Member) public members;
    mapping(address => uint256) public totalDeposits;

    // Wallet change workflow
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
        string memory _firstName,
        string memory _middleName,
        string memory _lastName,
        uint256 _dateOfBirth,
        uint256 _nationalIdHash,
        string memory _passportNumberHash,
        string memory _idDocumentHash,
        string memory _passportPhotoHash
    ) external {
        MemberSubmission storage sub = memberSubmissions[msg.sender];
        if (sub.submitted) revert MembershipErrors.AlreadySubmitted();
        if (bytes(_firstName).length == 0 || bytes(_middleName).length == 0 || bytes(_lastName).length == 0) revert MembershipErrors.InvalidData();
        if (_dateOfBirth == 0) revert MembershipErrors.InvalidData();
        if (_nationalIdHash == 0 && bytes(_passportNumberHash).length == 0)
            revert MembershipErrors.InvalidData();
        if (bytes(_idDocumentHash).length == 0 || bytes(_passportPhotoHash).length == 0)
            revert MembershipErrors.InvalidData();

        memberSubmissions[msg.sender] = MemberSubmission({
            firstName: _firstName,
            middleName: _middleName,
            lastName: _lastName,
            dateOfBirth: _dateOfBirth,
            nationalIdHash: _nationalIdHash,
            passportNumberHash: _passportNumberHash,
            idDocumentHash: _idDocumentHash,
            passportPhotoHash: _passportPhotoHash,
            submitted: true,
            submittedAt: block.timestamp
        });

        emit MembershipEvents.BiodataSubmitted(msg.sender, block.timestamp);
    }

    // --- ✅ APPROVE MEMBERSHIP ---
    function approveMembership(address applicant, bool makeGuarantor) external onlyAdmin {
        MemberSubmission memory sub = memberSubmissions[applicant];
        if (!sub.submitted) revert MembershipErrors.NoPendingApplication();

        members[applicant] = MembershipTypes.Member({
            name: string(abi.encodePacked(sub.firstName, " ", sub.lastName)),
            nationalId: sub.nationalIdHash,
            passportNumber: sub.passportNumberHash,
            phone: "",         // optional off-chain or future extension
            email: "",         // optional off-chain
            nextOfKinName: "",
            nextOfKinPhone: "",
            nextOfKinEmail: "",
            nextOfKinIdNumber: "",
            wallet: applicant,
            registeredAt: block.timestamp,
            isActive: true,
            isGuarantor: makeGuarantor,
            shares: MembershipShares.calculateSharesOnJoin()
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

        pendingWalletChanges[msg.sender] = newWallet;
        walletChangeVoteCount[msg.sender] = 0;

        emit MembershipEvents.WalletChangeRequested(msg.sender, newWallet);
    }

    function approveWalletChange(address member) external onlyApprover {
        if (pendingWalletChanges[member] == address(0)) revert MembershipErrors.NoWalletChangeRequest();
        if (walletChangeVotes[member][msg.sender]) revert MembershipErrors.AlreadyVoted();

        walletChangeVotes[member][msg.sender] = true;
        walletChangeVoteCount[member]++;

        emit MembershipEvents.WalletChangeApproved(member, pendingWalletChanges[member], msg.sender);

        if (walletChangeVoteCount[member] >= walletChangeQuorum) {
            members[member].wallet = pendingWalletChanges[member];
            delete pendingWalletChanges[member];
            delete walletChangeVoteCount[member];
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
    function getMemberSubmission(address user) external view returns (MemberSubmission memory) {
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
