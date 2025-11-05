// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ReserveFund {
    event Initialized(address indexed owner);

    constructor() {
        emit Initialized(msg.sender);
    }
}
