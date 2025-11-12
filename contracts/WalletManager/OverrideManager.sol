// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title OverrideManager
/// @notice Manages scoped admin overrides for WalletManager and related modules
contract OverrideManager {
    address public immutable owner;

    /// @notice Mapping of override permissions by wallet or module
    mapping(address => bool) public overrideEnabled;

    /// @notice Emitted when override is toggled
    event OverrideSet(address indexed target, bool enabled, address indexed by);

    modifier onlyOwner() {
        require(msg.sender == owner, "OverrideManager: not authorized");
        _;
    }

    constructor(address _owner) {
        require(_owner != address(0), "OverrideManager: zero address");
        owner = _owner;
    }

    /// @notice Enable or disable override for a target contract
    function setOverride(address target, bool enabled) external onlyOwner {
        require(target != address(0), "OverrideManager: invalid target");
        overrideEnabled[target] = enabled;
        emit OverrideSet(target, enabled, msg.sender);
    }

    /// @notice Check if override is active for a target
    function isOverrideActive(address target) external view returns (bool) {
        return overrideEnabled[target];
    }
}