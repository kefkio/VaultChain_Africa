// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import  "../lib/forge-std/src/Test.sol";
import {LoanManager} from "../contracts/loan/LoanManager.sol";
import {LoanCore} from "../contracts/loan/LoanCore.sol";
import {LoanLogic} from "../contracts/loan/LoanLogic.sol";
import {MembershipModule} from "../contracts/membership/MembershipModule.sol";
import {MembershipTypes} from "../contracts/membership/Membership_Types.sol";
import {LoanTypes} from "../contracts/loan/LoanTypes.sol";
  
contract MockOracle {
        function getLatestPrice() external pure returns (uint256) {
            return 1e18;
        }
    }
contract LoanManagerTest is Test {
    // Core contracts
    LoanManager loanManager;
    LoanCore loanCore;
    LoanLogic loanLogic;
    MembershipModule membership;
    MockOracle oracle;

    // Test actors
    address admin;
    address borrower;
    address guarantor;
    address tokenAddress;
    address[] operators;

    // Mock Oracle for testing
 

    // Setup function runs before each test
    function setUp() public {
        // Deploy dependencies
        membership = new MembershipModule();
        oracle = new MockOracle();
        loanCore = new LoanCore();
        loanLogic = new LoanLogic(address(loanCore), address(membership), address(oracle));

        // Initialize test actors
        admin = address(this);
        borrower = address(0xBEEF);
        guarantor = address(0xDEAD);
        tokenAddress = address(0xCAFE);

        // Initialize operators array with correct size
        operators = new address[](1);
        operators[0] = admin;

        // Approve borrower membership
        membership.approveMembership(borrower, MembershipTypes.MemberType.REGULAR, true);

        // Deploy and initialize LoanManager
        loanManager = new LoanManager();
        loanManager.initialize(
            address(loanCore),
            address(loanLogic),
            address(membership),
            admin,
            operators
        );
    }

    // Helper function for creating loans
    function createTestLoan() internal returns (uint256) {
        return loanCore.createLoan(
            borrower,
            1000 ether,
            30 days,
            500,
            100 ether,
            tokenAddress,
            LoanTypes.PaymentType.Token,
            tokenAddress,
            LoanTypes.LoanType.Personal
        );
    }

    // Test basic loan creation
    function testCreateLoan() public {
        uint256 loanId = createTestLoan();
        loanManager.setActiveLoan(borrower, loanId);
        
        assertEq(loanId, 1);
        assertEq(uint8(loanCore.getLoanStatus(loanId)), uint8(LoanTypes.LoanStatus.Requested));
        assertEq(loanManager.getActiveLoanId(borrower), loanId);
    }

    // Test loan repayment
    function testReduceLoanAmount() public {
        uint256 loanId = createTestLoan();
        loanManager.setActiveLoan(borrower, loanId);
        
        // Repay half
        vm.prank(borrower);
        loanLogic.repayLoan(loanId, 500 ether, borrower);
        
        (,,, uint256 amount, , , , ) = loanCore.getLoanDetails(loanId);
        assertEq(amount, 500 ether);
    }

    // Test over-repayment prevention
    function testOverRepayment() public {
        uint256 loanId = createTestLoan();
        loanManager.setActiveLoan(borrower, loanId);
        
        vm.prank(borrower);
        vm.expectRevert();
        loanLogic.repayLoan(loanId, 2000 ether, borrower);
    }

    // Test unauthorized actions
    function testFailNonAdminSetActiveLoan() public {
        uint256 loanId = createTestLoan();
        vm.prank(address(0x1234));
        vm.expectRevert();
        loanManager.setActiveLoan(borrower, loanId);
    }

    // Test multiple loans per borrower
    function testMultipleLoansPerBorrower() public {
        uint256 loan1 = createTestLoan();
        uint256 loan2 = createTestLoan();
        
        loanManager.setActiveLoan(borrower, loan1);
        assertEq(loanManager.getActiveLoanId(borrower), loan1);
        
        loanManager.setActiveLoan(borrower, loan2);
        assertEq(loanManager.getActiveLoanId(borrower), loan2);
        
        loanManager.clearActiveLoan(borrower);
        assertEq(loanManager.getActiveLoanId(borrower), 0);
    }

    // Test full loan lifecycle
   function testFullLoanLifecycle() public {
    uint256 loanId = createTestLoan();
    loanManager.setActiveLoan(borrower, loanId);

    assertEq(loanManager.getActiveLoanId(borrower), loanId);

    vm.prank(admin);
    loanCore.updateLoanStatus(loanId, LoanTypes.LoanStatus.FullyRepaid);
    loanManager.clearActiveLoan(borrower);

    (,,,,,,, LoanTypes.LoanStatus status) = loanCore.getLoanDetails(loanId);
    assertEq(uint8(status), uint8(LoanTypes.LoanStatus.FullyRepaid));
    assertEq(loanManager.getActiveLoanId(borrower), 0);

    // Attempt re-repayment should fail
    vm.prank(borrower);
    vm.expectRevert();
    loanLogic.repayLoan(loanId, 1 ether, borrower);
}

}