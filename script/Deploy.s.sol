// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

// Core contracts
import {VaultChain} from "../contracts/core/VaultChain.sol";
import {LoanManager} from "../contracts/loan/LoanManager.sol";
import {LoanCore} from "../contracts/loan/LoanCore.sol";
import {LoanLogicFixed} from "../contracts/loan/LoanLogicFixed.sol";
import {Marketplace} from "../contracts/marketplace/Marketplace.sol";
import {OracleAggregator} from "../contracts/oracle/OracleAggregator.sol";
import {PoolVaultERC4626} from "../contracts/pool/PoolVaultERC4626.sol";
import {Treasury} from "../contracts/treasury/Treasury.sol";
import {TimelockController} from "../contracts/governance/TimelockController.sol";

// WalletManager suite
import {WalletManager} from "../contracts/WalletManager/WalletManager.sol";
import {OverrideManager} from "../contracts/WalletManager/OverrideManager.sol";
import {WalletFactory} from "../contracts/WalletManager/WalletFactory.sol";
import {FeeManager} from "../contracts/WalletManager/FeeManager.sol";
import {Relayer} from "../contracts/WalletManager/Relayer.sol";

// Membership
import {MembershipModule} from "../contracts/membership/MembershipModule.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        address admin = msg.sender;

        // 1. Deploy MembershipModule
        MembershipModule membership = new MembershipModule();
        console.log("MembershipModule deployed at:", address(membership));

        // 2. Deploy LoanCore
        LoanCore loanCore = new LoanCore(address(membership));
        console.log("LoanCore deployed at:", address(loanCore));

        // 3. Deploy LoanLogicFixed
        LoanLogicFixed loanLogic = new LoanLogicFixed(
            address(loanCore),
            address(membership),
            admin
        );
        console.log("LoanLogicFixed deployed at:", address(loanLogic));

        // 4. Deploy LoanManager
        address[] memory operators = new address[](1);
        operators[0] = admin;
        LoanManager loanManager = new LoanManager();
        loanManager.initialize(
            address(loanCore),
            address(loanLogic),
            address(membership),
            admin,
            operators
        );
        console.log("LoanManager deployed at:", address(loanManager));

        // 5. Deploy WalletManager suite
        OverrideManager overrideManager = new OverrideManager(admin);
        console.log("OverrideManager deployed at:", address(overrideManager));

        WalletFactory walletFactory = new WalletFactory();
        console.log("WalletFactory deployed at:", address(walletFactory));

        FeeManager feeManager = new FeeManager();
        console.log("FeeManager deployed at:", address(feeManager));

        Relayer relayer = new Relayer(admin);
        console.log("Relayer deployed at:", address(relayer));

        // Prepare approvers array for WalletManager
        address[] memory approvers = new address[](3);
        approvers[0] = admin;
        approvers[1] = vm.addr(1); // another trusted address
        approvers[2] = vm.addr(2); // another trusted address


        WalletManager walletManager = new WalletManager(
            address(membership),
            address(walletFactory),
            address(feeManager),
            approvers,
            admin
        );
        console.log("WalletManager deployed at:", address(walletManager));

        // 6. Deploy VaultChain with full wiring
        VaultChain vaultChain = new VaultChain(
            address(membership),
            address(loanManager),
            payable(address(loanManager)),
            address(walletManager),
            address(overrideManager),
            address(walletFactory),
            address(feeManager),
            address(relayer),
            admin
        );
        console.log("VaultChain deployed at:", address(vaultChain));

        vm.stopBroadcast();
    }
}