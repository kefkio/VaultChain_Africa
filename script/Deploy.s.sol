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
import {MembershipModule} from "../contracts/membership/MembershipModule.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        
        // 1. Deploy MembershipModule
        MembershipModule membership = new MembershipModule();
        console.log("MembershipModule deployed at:", address(membership));
        
        // 2. Deploy LoanCore
        LoanCore loanCore = new LoanCore(address(membership));
        console.log("LoanCore deployed at:", address(loanCore));
        
        // 3. Deploy LoanLogicFixed
        address admin = msg.sender;
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
        
        // 5. Deploy VaultChain with default values
        VaultChain vaultChain = new VaultChain(
            address(membership),
            address(loanManager),
            payable(address(loanManager)),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0)
        );
        console.log("VaultChain deployed at:", address(vaultChain));
        
        vm.stopBroadcast();
    }
}