// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract GovernanceManager is AccessControl, ReentrancyGuard {
    // Roles
    bytes32 public constant GOVERNANCE_ROLE   = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant MODULE_ADMIN_ROLE = keccak256("MODULE_ADMIN_ROLE");

    // Module keys (examples – adjust to your actual modules)
    bytes32 public constant MODULE_LOAN_CORE      = keccak256("MODULE_LOAN_CORE");
    bytes32 public constant MODULE_LOAN_MANAGER   = keccak256("MODULE_LOAN_MANAGER");
    bytes32 public constant MODULE_MEMBERSHIP     = keccak256("MODULE_MEMBERSHIP");
    bytes32 public constant MODULE_WALLET_MANAGER = keccak256("MODULE_WALLET_MANAGER");

    // Events
    event ModuleRegistered(bytes32 indexed moduleKey, address indexed moduleAddress);
    event ModuleAdminAssigned(bytes32 indexed moduleKey, address indexed account);
    event AdminRotated(bytes32 indexed role, address oldAdmin, address newAdmin);
    event ModuleDeregistered(bytes32 indexed moduleKey);

    // Storage
    mapping(bytes32 => address) public registeredModules;
    mapping(bytes32 => bool)    public moduleActive;

    constructor(address superAdmin) {
        grantRole(DEFAULT_ADMIN_ROLE, superAdmin);
        grantRole(GOVERNANCE_ROLE, superAdmin);

        // Governance controls module admins
        _setRoleAdmin(MODULE_ADMIN_ROLE, GOVERNANCE_ROLE);
    }

    // Module Management
    function registerModule(bytes32 moduleKey, address moduleAddress) 
        external 
        onlyRole(GOVERNANCE_ROLE) 
        nonReentrant 
    {
        require(moduleAddress != address(0), "Invalid module address");
        require(registeredModules[moduleKey] == address(0), "Module key already in use");
        
        registeredModules[moduleKey] = moduleAddress;
        moduleActive[moduleKey] = true;
        
        emit ModuleRegistered(moduleKey, moduleAddress);
    }

    function deregisterModule(bytes32 moduleKey) 
        external 
        onlyRole(GOVERNANCE_ROLE) 
        nonReentrant 
    {
        require(registeredModules[moduleKey] != address(0), "Module not registered");
        
        registeredModules[moduleKey] = address(0);
        moduleActive[moduleKey] = false;
        
        emit ModuleDeregistered(moduleKey);
    }

    function assignModuleAdmin(bytes32 moduleKey, address account) 
        external 
        onlyRole(GOVERNANCE_ROLE) 
        nonReentrant 
    {
        require(registeredModules[moduleKey] != address(0), "Module not registered");
        require(account != address(0), "Invalid account");
        
        grantRole(MODULE_ADMIN_ROLE, account);
        
        emit ModuleAdminAssigned(moduleKey, account);
    }

    function rotateAdmin(bytes32 role, address oldAdmin, address newAdmin) 
        external 
        onlyRole(GOVERNANCE_ROLE) 
        nonReentrant 
    {
        require(oldAdmin != address(0), "Invalid old admin");
        require(newAdmin != address(0), "Invalid new admin");
        require(newAdmin != oldAdmin, "New admin cannot be the same as old admin");
        
        revokeRole(role, oldAdmin);
        grantRole(role, newAdmin);
        
        emit AdminRotated(role, oldAdmin, newAdmin);
    }

    function setModuleStatus(bytes32 moduleKey, bool status) 
        external 
        onlyRole(GOVERNANCE_ROLE) 
        nonReentrant 
    {
        require(registeredModules[moduleKey] != address(0), "Module not registered");
        
        moduleActive[moduleKey] = status;
    }

    // View Functions
    function getModule(bytes32 moduleKey) external view returns (address) {
        return registeredModules[moduleKey];
    }

    function isModuleActive(bytes32 moduleKey) external view returns (bool) {
        return moduleActive[moduleKey];
    }
}
