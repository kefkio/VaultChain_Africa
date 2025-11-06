// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../contracts/loan/SaccoLoanManager.sol";
import "../contracts/IMembership.sol";

// Mock Membership contract for testing
contract MockMembership is IMembership {
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
        return ("", "", "", "", 0,0,0,0,0,0, registeredAtMap[member], isActiveMap[member]);
    }

    function getMemberWallet(address member) external view override returns (address) {
        return wallets[member];
    }
}

contract SaccoLoanManagerTest is Test {
    SaccoLoanManager public loanManager;
    MockMembership public membership;
    address public admin = address(0xABCD);
    address public operator = address(0xDEAD);
    address public member = address(0xBEEF);

    address[] public operators;
    address[] public guarantors;

    function setUp() public {
        // Setup mock membership
        membership = new MockMembership();
        membership.setMember(member, true, block.timestamp - 200 days, member);

        operators.push(operator);

        // Deploy loan manager
        loanManager = new SaccoLoanManager(admin, operators, address(membership));

        // Register member
        vm.prank(member);
        loanManager.registerMember();
        loanManager.updateKyc(member, SaccoLoanManager.KycStatus.Verified);

        // Setup guarantors
        guarantors.push(address(0xC0DE));
        membership.setMember(guarantors[0], true, block.timestamp - 200 days, guarantors[0]);
        loanManager.registerMemberFor(guarantors[0]);
        loanManager.updateKyc(guarantors[0], SaccoLoanManager.KycStatus.Verified);
    }

    function testRequestLoan() public {
        vm.prank(member);
        uint256 loanId = loanManager.requestLoan(
            1000 ether,
            SaccoLoanManager.PaymentType.Native,
            address(0),
            1,
            30 days,
            guarantors
        );

        (address borrower,, , uint256 guarantorCount, uint256 amount,, uint256 duration,, ) = loanManager.getLoanDetails(loanId);

        assertEq(borrower, member);
        assertEq(guarantorCount, 1);
        assertEq(amount, 1000 ether);
        assertEq(duration, 30 days);
    }

    function testApproveLoan() public {
        vm.prank(member);
        uint256 loanId = loanManager.requestLoan(
            1000 ether,
            SaccoLoanManager.PaymentType.Native,
            address(0),
            1,
            30 days,
            guarantors
        );

        vm.prank(operator);
        loanManager.approveLoan(loanId);

        (, , , , , , , , SaccoLoanManager.LoanStatus status) = loanManager.getLoanDetails(loanId);
        assertEq(uint(status), uint(SaccoLoanManager.LoanStatus.Approved));
    }

    function testDisburseLoan() public {
        vm.prank(member);
        uint256 loanId = loanManager.requestLoan(
            1 ether,
            SaccoLoanManager.PaymentType.Native,
            address(0),
            1,
            30 days,
            guarantors
        );

        vm.prank(operator);
        loanManager.approveLoan(loanId);

        // Fund the contract for native disbursement
        payable(address(loanManager)).transfer(1 ether);

        vm.prank(operator);
        loanManager.disburseLoan(loanId);

        (, , , , , , , , SaccoLoanManager.LoanStatus status) = loanManager.getLoanDetails(loanId);
        assertEq(uint(status), uint(SaccoLoanManager.LoanStatus.Disbursed));
    }

    receive() external payable {}
}