// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./InternalSmartWallet.sol";

contract WalletFactory {
    event WalletDeployed(address indexed member, address wallet);

    mapping(address => address) public memberWallets;

    function deployWallet(address member) external returns (address) {
        require(memberWallets[member] == address(0), "Already assigned");

        InternalSmartWallet wallet = new InternalSmartWallet(member);
        memberWallets[member] = address(wallet);

        emit WalletDeployed(member, address(wallet));
        return address(wallet);
    }
}
