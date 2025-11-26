// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

import "./GovernanceManager.sol";
import "./GovernanceMultisig.sol";
import "../loan/LoanCore.sol";

contract GovernanceModule is AccessControl, ReentrancyGuard {
    // ---------- Events ----------
    event ModuleInitialized(address indexed admin);
    event GovernanceWired(
        address governanceManager,
        address timelock,
        address multisig
    );
    event ProposalQueued(bytes32 indexed proposalId, address indexed proposer);
    event ProposalExecuted(bytes32 indexed proposalId);

    // ---------- Roles ----------
    bytes32 public constant SUPER_ADMIN_ROLE      = keccak256("SUPER_ADMIN_ROLE");
    bytes32 public constant GOVERNANCE_ADMIN_ROLE = keccak256("GOVERNANCE_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE         = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE         = keccak256("EXECUTOR_ROLE");

    // ---------- Governance Components ----------
    GovernanceManager   public governanceManager;
    TimelockController  public timelock;
    GovernanceMultisig  public multisig;

    // ---------- Constructor ----------
    constructor(address admin) {
        require(admin != address(0), "Invalid admin address");

        grantRole(DEFAULT_ADMIN_ROLE, admin);
        grantRole(SUPER_ADMIN_ROLE, admin);
        grantRole(GOVERNANCE_ADMIN_ROLE, admin);
        grantRole(PROPOSER_ROLE, admin);
        grantRole(EXECUTOR_ROLE, admin);

        emit ModuleInitialized(admin);
    }

    // ---------- One-time wiring ----------
    function wireGovernance(
        address _governanceManager,
        address _timelock,
        address _multisig
    ) external onlyRole(SUPER_ADMIN_ROLE) {
        require(address(governanceManager) == address(0), "Already wired");
        require(_governanceManager != address(0), "Invalid GM");
        require(_timelock != address(0), "Invalid timelock");
        require(_multisig != address(0), "Invalid multisig");

        governanceManager = GovernanceManager(_governanceManager);
        timelock = TimelockController(payable(_timelock));
        multisig = GovernanceMultisig(_multisig);

        emit GovernanceWired(_governanceManager, _timelock, _multisig);
    }

    // ---------------------------------------------------------------------
    // Governance wrapper for proposals using TimelockController
    // ---------------------------------------------------------------------
    
// Mapping to track executed proposals for extra safety
mapping(bytes32 => bool) private _executedProposals;

function queueAction(
    address target,
    uint256 value,
    bytes calldata data,
    bytes32 predecessor,
    bytes32 salt,
    uint256 delay
) external onlyRole(PROPOSER_ROLE) returns (bytes32) {
    require(address(timelock) != address(0), "Timelock not set");

    // Compute proposal ID
    bytes32 proposalId = timelock.hashOperation(target, value, data, predecessor, salt);

    // Emit event first
    emit ProposalQueued(proposalId, msg.sender);

    // External call last
    timelock.schedule(target, value, data, predecessor, salt, delay);

    return proposalId;
}

function executeAction(
    address target,
    uint256 value,
    bytes calldata data,
    bytes32 predecessor,
    bytes32 salt
) external onlyRole(EXECUTOR_ROLE) returns (bytes32) {
    require(address(timelock) != address(0), "Timelock not set");

    // Compute proposal ID
    bytes32 proposalId = timelock.hashOperation(target, value, data, predecessor, salt);

    // Prevent double execution (defense-in-depth)
    require(!_executedProposals[proposalId], "Already executed");
    _executedProposals[proposalId] = true;

    // Emit event before the external call
    emit ProposalExecuted(proposalId);

    // External call last
    timelock.execute(target, value, data, predecessor, salt);

    return proposalId;
}


    // ---------------------------------------------------------------------
    // Helpers to register/flag modules via GovernanceManager
    // ---------------------------------------------------------------------
    function registerModule(bytes32 moduleKey, address moduleAddress)
        external onlyRole(GOVERNANCE_ADMIN_ROLE)
    {
        governanceManager.registerModule(moduleKey, moduleAddress);
    }

    function setModuleStatus(bytes32 moduleKey, bool status)
        external onlyRole(GOVERNANCE_ADMIN_ROLE)
    {
        governanceManager.setModuleStatus(moduleKey, status);
    }

    function assignModuleAdmin(bytes32 moduleKey, address account)
        external onlyRole(GOVERNANCE_ADMIN_ROLE)
    {
        governanceManager.assignModuleAdmin(moduleKey, account);
    }

    function rotateModuleAdmin(address oldAdmin, address newAdmin)
        external onlyRole(GOVERNANCE_ADMIN_ROLE)
    {
        governanceManager.rotateAdmin(
            governanceManager.MODULE_ADMIN_ROLE(),
            oldAdmin,
            newAdmin
        );
    }

    // ---------- View Helpers ----------
    function getModule(bytes32 moduleKey) external view returns (address) {
        return governanceManager.getModule(moduleKey);
    }

    function isModuleActive(bytes32 moduleKey) external view returns (bool) {
        return governanceManager.isModuleActive(moduleKey);
    }
}
