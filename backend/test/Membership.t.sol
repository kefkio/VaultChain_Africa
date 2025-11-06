// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../contracts/membership/Membership.sol";

contract MembershipModuleTest is Test {
    MembershipModule public membership;

    address public admin;
    address public user1;
    address public user2;
    address public fakeWallet = address(0x1234);

    event BiodataSubmitted(address indexed member, uint256 timestamp);
    event MemberApproved(address indexed member, uint256 shares, bool isGuarantor);

    function setUp() public {
        admin = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        membership = new MembershipModule();
    }

    // --- Test: Submit biodata successfully ---
    function testSubmitBiodataSuccess() public {
        vm.prank(user1);

        // Expect event first
        vm.expectEmit(true, false, false, true);
        emit BiodataSubmitted(user1, block.timestamp);

        membership.submitBiodata(
            "Alice",
            uint256(keccak256(abi.encodePacked("12345678"))),
            string(abi.encodePacked(keccak256(abi.encodePacked("P123456")))),
            "hash_of_id_doc",
            "hash_of_passport_photo"
        );

        MembershipModule.MemberSubmission memory sub = membership.getMemberSubmission(user1);

        assertEq(sub.name, "Alice");
        assertTrue(sub.submitted);
        assertGt(sub.submittedAt, 0);
    }

    // --- Test: Duplicate submission should revert ---
    function testSubmitBiodataDuplicateReverts() public {
        vm.prank(user1);
        membership.submitBiodata(
            "Alice",
            uint256(keccak256(abi.encodePacked("12345678"))),
            string(abi.encodePacked(keccak256(abi.encodePacked("P123456")))),
            "hash_of_id_doc",
            "hash_of_passport_photo"
        );

        vm.prank(user1);
        vm.expectRevert(MembershipModule.MembershipErrors.AlreadySubmitted.selector);
        membership.submitBiodata(
            "Alice",
            uint256(keccak256(abi.encodePacked("12345678"))),
            string(abi.encodePacked(keccak256(abi.encodePacked("P123456")))),
            "hash_of_id_doc",
            "hash_of_passport_photo"
        );
    }

    // --- Test: Approve member as admin ---
    function testApproveMember() public {
        vm.prank(user2);
        membership.submitBiodata(
            "Bob",
            uint256(keccak256(abi.encodePacked("87654321"))),
            string(abi.encodePacked(keccak256(abi.encodePacked("P654321")))),
            "hash_of_id_doc",
            "hash_of_passport_photo"
        );

        // Expect event before approving
        vm.expectEmit(true, false, false, true);
        emit MemberApproved(user2, 1, true);

        // Admin approves
        vm.prank(admin);
        membership.approveMembership(user2, true);

        assertTrue(membership.isMember(user2));
        assertTrue(membership.isGuarantor(user2));
        assertEq(membership.getShares(user2), 1);
    }

    // --- Test: Non-member deposit should revert ---
    function testDepositNonMemberReverts() public {
        vm.expectRevert(MembershipModule.MembershipErrors.NotAMember.selector);
        membership.deposit{value: 1 ether}(user1);
    }

    // --- Test: Deposit for approved member ---
    function testDepositForMember() public {
        vm.prank(user2);
        membership.submitBiodata(
            "Bob",
            uint256(keccak256(abi.encodePacked("87654321"))),
            string(abi.encodePacked(keccak256(abi.encodePacked("P654321")))),
            "hash_of_id_doc",
            "hash_of_passport_photo"
        );

        vm.prank(admin);
        membership.approveMembership(user2, false);

        vm.deal(user2, 2 ether);
        vm.prank(user2);
        membership.deposit{value: 1 ether}(user2);

        uint256 total = membership.getTotalDeposits(user2);
        assertEq(total, 1 ether);
    }
}
