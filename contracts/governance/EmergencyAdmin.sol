// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EmergencyAdmin {

    event Initialized(address indexed owner);

    constructor() {
        emit Initialized(msg.sender);
    }
}
