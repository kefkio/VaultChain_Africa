// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../contracts/loan/LoanManager.sol";
import "../contracts/membership/IMembershipModule.sol";

contract MockMembership is IMembershipModule {
    mapping(address => bool) public members;
    mapping(address => address) public wallets;
    mapping(address => uint256) public registeredAtMap;
    mapping(address => bool) public isActiveMap;

    function setMember(address member, bool active, uint256 registeredAt, address wallet) public {
        members[member] = true;
        isActiveMap[member] = active;
        registeredAtMap[member] = registeredAt;
        wallets[member] = wallet;
    }

    function isMember(address member) external view override returns (bool) {
        return members[member];
    }

    function getMember(address member) external view override returns (
        string memory, string memory, string memory, string memory, uint256, uint256, uint256, uint256, uint256, uint256, uint256, bool
    ) {
        return ("", "", "", "", 0, 0, 0, 0, 0, 0, registeredAtMap[member], isActiveMap[member]);
    }

    function getMemberWallet(address member) external view override returns (address) {
        return wallets[member];
    }
}

contract SaccoLoanManagerTest is Test {
    LoanManager public loanManager;
    MockMembership public membership;
    address public admin = address(0xABCD);
    address public operator = address(0xDEAD);
    address public member = address(0xBEEF);

    address[] public operators;
    address[] public guarantors;

    function setUp() public {
        membership = new MockMembership();
        membership.setMember(member, true, block.timestamp - 200 days, member);

        operators.push(operator);

        loanManager = new LoanManager(admin, operators, address(membership));

        vm.prank(member);
        loanManager.registerMember();
        loanManager.updateKyc(member, LoanManager.KycStatus.Verified);

        guarantors.push(address(0xC0DE));
        membership.setMember(guarantors[0], true, block.timestamp - 200 days, guarantors[0]);
        loanManager.registerMemberFor(guarantors[0]);
        loanManager.updateKyc(guarantors[0], LoanManager.KycStatus.Verified);
    }

    // ... Add testRequestLoan, testApproveLoan, testDisburseLoan
}
