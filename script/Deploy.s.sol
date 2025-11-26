// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {MembershipModule} from "../contracts/membership/MembershipModule.sol";
import {LoanCore} from "../contracts/loan/LoanCore.sol";
import {LoanLogic} from "../contracts/loan/LoanLogic.sol";
import {LoanManager} from "../contracts/loan/LoanManager.sol";
import {GovernanceMultisig} from "../contracts/governance/GovernanceMultisig.sol";
import {TimelockController} from "../contracts/governance/TimelockController.sol";

contract Deploy is Script {
    address public deployer;
    address public oracleAddress;

    function setUp() public {
        deployer = vm.envOr("DEPLOYER", address(0));
        if (deployer == address(0)) {
            deployer = msg.sender;
        }

        // placeholder for your oracle
        oracleAddress = address(0xDEAD);
    }

    function run() public {
        // Declare arrays before use
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        address[] memory owners    = new address[](2);
        address[] memory operators = new address[](1);

        vm.startBroadcast(deployer);

        // 1. Deploy Membership Module
        MembershipModule membership = new MembershipModule();

        // 2. Deploy TimelockController
        uint256 minDelay = 2 days;
        proposers[0] = deployer;
        executors[0] = deployer;

        TimelockController timelock = new TimelockController(
            minDelay,
            proposers,
            executors,
            deployer // admin
        );

        // 3. Deploy LoanCore
        LoanCore loanCore = new LoanCore();

        // 4. Deploy LoanLogic
        LoanLogic loanLogic = new LoanLogic(
            address(loanCore),
            address(membership),
            oracleAddress // adjust to match your LoanLogic constructor
        );

        // 5. Deploy LoanManager
        LoanManager loanManager = new LoanManager();

        // 6. Deploy GovernanceMultisig
        owners[0] = deployer;        // replace with your actual admin address
        owners[1] = oracleAddress;   // replace with another signer address

        uint256 threshold = 2;       // approvals required
        GovernanceMultisig governance = new GovernanceMultisig(
            address(timelock),
            owners,
            threshold
        );

        // 7. Update timelock roles to GovernanceMultisig
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governance));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governance));

        // Optionally revoke deployer's roles
        timelock.revokeRole(timelock.PROPOSER_ROLE(), deployer);
        timelock.revokeRole(timelock.EXECUTOR_ROLE(), deployer);

        // 8. Initialize LoanManager
        operators[0] = deployer;
        loanManager.initialize(
            address(loanCore),
            address(loanLogic),
            address(membership),
            deployer,
            operators
        );

        // 9. Grant LOGIC_ROLE to LoanLogic instance so it can call LoanCore
        loanCore.grantRole(loanCore.LOGIC_ROLE(), address(loanLogic));

        vm.stopBroadcast();

        console2.log("Deployer:           ", deployer);
        console2.log("MembershipModule:   ", address(membership));
        console2.log("TimelockController: ", address(timelock));
        console2.log("LoanCore:           ", address(loanCore));
        console2.log("LoanLogic:          ", address(loanLogic));
        console2.log("LoanManager:        ", address(loanManager));
        console2.log("GovernanceMultisig: ", address(governance));
    }
}