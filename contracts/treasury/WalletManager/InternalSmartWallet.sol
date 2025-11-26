// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract InternalSmartWallet {
    address public owner;
    mapping(address => bool) public sessionKeys;
    bool public active;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAuthorized() {
        require(msg.sender == owner || sessionKeys[msg.sender], "Unauthorized");
        _;
    }

    constructor(address _owner) {
        owner = _owner;
        active = true;
    }

    function execute(address target, bytes calldata data) external onlyAuthorized {
        require(active, "Wallet inactive");
        (bool success, ) = target.call(data);
        require(success, "Execution failed");
    }

    function addSessionKey(address key) external onlyOwner {
        sessionKeys[key] = true;
    }

    function removeSessionKey(address key) external onlyOwner {
        sessionKeys[key] = false;
    }

    function deactivate() external onlyOwner {
        active = false;
    }
}