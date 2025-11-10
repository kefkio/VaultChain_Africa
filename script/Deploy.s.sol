// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

// Core contracts
import {VaultChain} from "../contracts/core/VaultChain.sol";
import {LoanManager} from "../contracts/loan/LoanManager.sol";
import {Marketplace} from "../contracts/marketplace/Marketplace.sol";
import {OracleAggregator} from "../contracts/oracle/OracleAggregator.sol";
import {PoolVaultERC4626} from "../contracts/pool/PoolVaultERC4626.sol";
import {Treasury} from "../contracts/treasury/Treasury.sol";
import {TimelockController} from "../contracts/governance/TimelockController.sol";
import {MembershipModule} from "../contracts/membership/MembershipModule.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        // --- Deploy dependencies first ---
        MembershipModule membership = new MembershipModule();
        Treasury treasury = new Treasury();
        OracleAggregator oracle = new OracleAggregator();

        // --- Prepare operator list for LoanManager ---
        address[] memory operators = new address[](1);
        operators[0] = msg.sender;

        // --- Deploy LoanManager with constructor args ---
        LoanManager loanManager = new LoanManager(
            msg.sender,         // admin
            operators,          // operator list
            address(membership) // membership module
        );

        // --- Deploy remaining modules ---
        Marketplace marketplace = new Marketplace();
        PoolVaultERC4626 poolVault = new PoolVaultERC4626();
        TimelockController timelock = new TimelockController();

        // --- Deploy VaultChain with module addresses ---
        VaultChain vaultChain = new VaultChain(
    address(loanManager),
    address(membership),
    address(marketplace),
    address(oracle),
    address(poolVault),
    address(treasury),
    address(timelock),
    100,                                  // fee value
    0x1234567890123456789012345678901234567890 // some token address
);


        // --- Console logs for humans ---
        console.log("VaultChain deployed at:         ", address(vaultChain));
        console.log("MembershipModule deployed at:   ", address(membership));
        console.log("LoanManager deployed at:        ", address(loanManager));
        console.log("Marketplace deployed at:        ", address(marketplace));
        console.log("OracleAggregator deployed at:   ", address(oracle));
        console.log("PoolVaultERC4626 deployed at:   ", address(poolVault));
        console.log("Treasury deployed at:           ", address(treasury));
        console.log("TimelockController deployed at: ", address(timelock));

        // --- Parser-friendly logs for automation ---
        console.log("DeployedContract:MembershipModule:%s", address(membership));
        console.log("DeployedContract:VaultChain:%s", address(vaultChain));
        console.log("DeployedContract:LoanManager:%s", address(loanManager));
        console.log("DeployedContract:Marketplace:%s", address(marketplace));
        console.log("DeployedContract:OracleAggregator:%s", address(oracle));
        console.log("DeployedContract:PoolVaultERC4626:%s", address(poolVault));
        console.log("DeployedContract:Treasury:%s", address(treasury));
        console.log("DeployedContract:TimelockController:%s", address(timelock));

        vm.stopBroadcast();
    }
}