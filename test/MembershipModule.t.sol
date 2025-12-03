// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import  "../lib/forge-std/src/Test.sol";
import "../contracts/membership/MembershipModule.sol";
import "../contracts/membership/Membership_Types.sol";

contract MembershipModuleTest is Test {
    MembershipModule public membership;

    address public admin = address(0xABCD);
    address public approver = address(0xDEAD);
    address public member = address(0xBEEF);
    address public newWallet = address(0xC0DE);

    function setUp() public {
        // Deploy MembershipModule as admin
        vm.prank(admin);
        membership = new MembershipModule();

        // Add approver as admin
        vm.prank(admin);
        membership.addApprover(approver);

        // Give member some ETH for deposits
        vm.deal(member, 5 ether);
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

    // --- 🔄 Full Membership Lifecycle Integration Test ---
    function testFullMembershipLifecycle() public {
        address finalWallet = address(0xFEED);

        // --- Step 1: Member submits biodata ---
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

        // --- Step 2: Admin approves membership ---
        vm.prank(admin);
        membership.approveMembership(member, MembershipTypes.MemberType.PREMIUM, true);
        assertTrue(membership.isMember(member));
        assertGt(membership.getShares(member), 0);

        // --- Step 3: Member deposits 2 ETH ---
        vm.prank(member);
        membership.deposit{value: 2 ether}(member);
        assertEq(membership.getTotalDeposits(member), 2 ether);

        // --- Step 4: Member requests wallet change ---
        vm.prank(member);
        membership.requestWalletChange(finalWallet);

        // --- Step 5: Approver approves wallet change ---
        vm.prank(approver);
        membership.approveWalletChange(member);
        assertEq(membership.getMemberWallet(member), finalWallet);

        // --- Step 6: Capture initial balance for refund check ---
        uint256 initialBalance = member.balance;

        // --- Step 7: Admin revokes membership ---
        vm.prank(admin);
        membership.revokeMembership(member);

        assertFalse(membership.isMember(member));
        assertEq(membership.getShares(member), 0);

        // --- Step 8: Refund deposits ---
        uint256 refunded = membership.refundDeposits(member);
        assertEq(refunded, 2 ether);
        assertEq(member.balance, initialBalance + 2 ether);
        assertEq(membership.getTotalDeposits(member), 0);
    }

    receive() external payable {}
}
