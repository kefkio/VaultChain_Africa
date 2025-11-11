// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../contracts/membership/MembershipModule.sol";
import "../contracts/membership/Membership_Types.sol";

contract MembershipModuleTest is Test {
    MembershipModule public membership;

    address public admin = address(0xABCD);
    address public approver = address(0xDEAD);
    address public member = address(0xBEEF);
    address public newWallet = address(0xC0DE);

    function setUp() public {
        membership = new MembershipModule();
        vm.prank(admin);
        membership.addApprover(approver);
    }

    // --- 📝 Biodata Submission ---
    function testSubmitBiodata() public {
        vm.prank(member);
        membership.submitBiodata(
            "Kefa", "Kioge", "Test",
            946684800,
            123456789,
            "passportHash",
            "idDocHash",
            "passportPhotoHash"
        );

        MembershipStructs.MemberSubmission memory sub = membership.getMemberSubmission(member);
        assertTrue(sub.submitted);
        assertEq(sub.firstName, "Kefa");
        assertEq(sub.nationalIdHash, 123456789);
    }

    function testSubmitBiodataFailsTwice() public {
        vm.prank(member);
        membership.submitBiodata("Kefa", "Kioge", "Test", 946684800, 123456789, "passportHash", "idDocHash", "passportPhotoHash");

        vm.prank(member);
        vm.expectRevert(MembershipErrors.AlreadySubmitted.selector);
        membership.submitBiodata("Kefa", "Kioge", "Test", 946684800, 123456789, "passportHash", "idDocHash", "passportPhotoHash");
    }

    // --- ✅ Membership Approval ---
    function testApproveMembership() public {
        vm.prank(member);
        membership.submitBiodata("Kefa", "Kioge", "Test", 946684800, 123456789, "passportHash", "idDocHash", "passportPhotoHash");

        vm.prank(admin);
        membership.approveMembership(member, MembershipTypes.MemberType.PREMIUM, true);

        assertTrue(membership.isMember(member));
        assertTrue(membership.isGuarantor(member));
        assertGt(membership.getShares(member), 0);
    }

    // --- 💰 Deposit Handling ---
    function testDeposit() public {
        vm.prank(member);
        membership.submitBiodata("Kefa", "Kioge", "Test", 946684800, 123456789, "passportHash", "idDocHash", "passportPhotoHash");

        vm.prank(admin);
        membership.approveMembership(member, MembershipTypes.MemberType.REGULAR, false);

        vm.prank(member);
        membership.deposit{value: 1 ether}(member);

        assertEq(membership.getTotalDeposits(member), 1 ether);
    }

    // --- 🔄 Wallet Change Flow ---
    function testWalletChange() public {
        vm.prank(member);
        membership.submitBiodata("Kefa", "Kioge", "Test", 946684800, 123456789, "passportHash", "idDocHash", "passportPhotoHash");

        vm.prank(admin);
        membership.approveMembership(member, MembershipTypes.MemberType.REGULAR, false);

        vm.prank(member);
        membership.requestWalletChange(newWallet);

        vm.prank(approver);
        membership.approveWalletChange(member);

        assertEq(membership.getMemberWallet(member), newWallet);
    }

    // --- 🔐 Admin Controls ---
    function testAddRemoveApprover() public {
        address newApprover = address(0xBABA);

        vm.prank(admin);
        membership.addApprover(newApprover);

        vm.expectRevert();
        membership.addApprover(address(0));

        vm.prank(admin);
        membership.removeApprover(newApprover);
    }

    receive() external payable {}
}