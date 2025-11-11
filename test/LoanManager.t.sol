// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../contracts/loan/LoanManager.sol";
import "../contracts/core/interfaces/IMembershipModule.sol";
import "../contracts/membership/Membership_Types.sol";

// -----------------------------
// Mock Membership Module
// -----------------------------
abstract contract MockMembership is IMembershipModule {
    mapping(address => bool) public members;
    mapping(address => address) public wallets;
    mapping(address => uint256) public registeredAtMap;
    mapping(address => bool) public isActiveMap;

    // Setup a member for tests
    function setMember(address member, bool active, uint256 registeredAt, address wallet) public {
        members[member] = true;
        isActiveMap[member] = active;
        registeredAtMap[member] = registeredAt;
        wallets[member] = wallet;
    }

    // --- IMembershipModule implementation ---
    function isMember(address user) external view override returns (bool) {
        return members[user];
    }

    function getMember(address user)
        external
        view
        override
        returns (MembershipTypes.Member memory)
    {
        return MembershipTypes.Member({
    name: "",
    nationalIdHash: 0,
    passportNumberHash: "",
    phone: "",
    email: "",
    nextOfKinName: "",
    nextOfKinPhone: "",
    nextOfKinEmail: "",
    nextOfKinIdNumber: "",
    wallet: wallets[user],
    registeredAt: registeredAtMap[user],
    isActive: isActiveMap[user],
    isGuarantor: false,
    shares: 0,
    memberType: MembershipTypes.MemberType.REGULAR  // <-- use uppercase
});

    }

    function getMemberWallet(address user) external view override returns (address) {
        return wallets[user];
    }

    // --- Stub implementations for all other functions in IMembershipModule ---
    function addApprover(address) external override {}
    function removeApprover(address) external override {}
    function approveMembership(address, bool) external override {}
    function submitBiodata(
        string memory,
        string memory,
        string memory,
        uint256,
        uint256,
        string memory,
        string memory,
        string memory
    ) external override {}
    function updateMemberWallet(address, address) external override {}
    function walletChangeQuorum() external view override returns (uint256) {
        return 1;
    }
    function isGuarantor(address) external view override returns (bool) {
        return false;
    }
    function getShares(address) external view override returns (uint256) {
        return 0;
    }
    function getTotalDeposits(address) external view override returns (uint256) {
        return 0;
    }
}

// -----------------------------
// Sacco LoanManager Test
// -----------------------------
contract SaccoLoanManagerTest is Test {
    LoanManager public loanManager;
    MockMembership public membership;

    address public admin = address(0xABCD);
    address public operator = address(0xDEAD);
    address public member = address(0xBEEF);

    address[] public operators;
    address[] public guarantors;

    function setUp() public {
        // Deploy mock membership
        membership = new MockMembership();
        membership.setMember(member, true, block.timestamp - 200 days, member);

        // Set operator
        operators.push(operator);

        // Deploy LoanManager
        loanManager = new LoanManager(admin, operators, address(membership));

        // Register member in LoanManager
        vm.prank(member);
        loanManager.registerMember();
        loanManager.updateKyc(member, LoanManager.KycStatus.Verified);

        // Setup guarantor
        guarantors.push(address(0xC0DE));
        membership.setMember(guarantors[0], true, block.timestamp - 200 days, guarantors[0]);
        loanManager.registerMemberFor(guarantors[0]);
        loanManager.updateKyc(guarantors[0], LoanManager.KycStatus.Verified);
    }

    // Example test stubs
    function testRequestLoan() public {
        vm.prank(member);
        uint256 loanId = loanManager.requestLoan(
            1000 ether,
            LoanManager.PaymentType.Native,
            address(0),
            1,
            30 days,
            guarantors
        );

        (
            address borrower,
            ,
            ,
            uint256 guarantorCount,
            uint256 amount,
            ,
            uint256 duration,
            ,
        ) = loanManager.getLoanDetails(loanId);

        assertEq(borrower, member);
        assertEq(guarantorCount, 1);
        assertEq(amount, 1000 ether);
        assertEq(duration, 30 days);
    }

    // More tests like testApproveLoan, testDisburseLoan can be added here
}
