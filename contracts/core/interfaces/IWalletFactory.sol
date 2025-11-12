// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IWalletFactory {
    function memberWallets(address member) external view returns (address);
    function deployWallet(address member) external returns (address);
}