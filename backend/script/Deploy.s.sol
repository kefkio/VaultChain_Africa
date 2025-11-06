// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Named imports to satisfy Forge lint
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

// Import core contracts using project-relative paths
import {VaultChain} from "backend/contracts/core/VaultChain.sol";
import {LoanManager} from "backend/contracts/loan/LoanManager.sol";
import {Marketplace} from "backend/contracts/marketplace/Marketplace.sol";
import {OracleAggregator} from "backend/contracts/oracle/OracleAggregator.sol";
import {PoolVaultERC4626} from "backend/contracts/pool/PoolVaultERC4626.sol";
import {Treasury} from "backend/contracts/treasury/Treasury.sol";
import {TimelockController} from "backend/contracts/governance/TimelockController.sol";
import {MembershipModule} from "backend/contracts/membership/MembershipModule.sol";

contract Deploy is Script {
    function run() external {
        // Start broadcasting transactions using the Anvil test account
        vm.startBroadcast(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);

        // Deploy core modules
        LoanManager loanManager = new LoanManager();
        MembershipModule membership = new MembershipModule();
        Marketplace marketplace = new Marketplace();
        OracleAggregator oracle = new OracleAggregator();
        PoolVaultERC4626 poolVault = new PoolVaultERC4626();
        Treasury treasury = new Treasury();
        TimelockController timelock = new TimelockController();

        // Deploy main VaultChain contract with module addresses
        VaultChain vaultChain = new VaultChain(
            address(loanManager),
            address(membership),
            address(marketplace),
            address(oracle),
            address(poolVault),
            address(treasury),
            address(timelock)
        );

        // --- Regular console logs for debugging ---
        console.log("VaultChain deployed at:       ", address(vaultChain));
        console.log("MembershipModule deployed at:", address(membership));
        console.log("LoanManager deployed at:     ", address(loanManager));
        console.log("Marketplace deployed at:     ", address(marketplace));
        console.log("OracleAggregator deployed at:", address(oracle));
        console.log("PoolVaultERC4626 deployed at:", address(poolVault));
        console.log("Treasury deployed at:        ", address(treasury));
        console.log("TimelockController deployed at:", address(timelock));

        // --- Parser-friendly logs for vc_automation.py ---
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
