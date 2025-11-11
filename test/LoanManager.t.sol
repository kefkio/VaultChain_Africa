// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {LoanManager} from "../contracts/loan/LoanManager.sol";
import {LoanCore} from "../contracts/loan/LoanCore.sol";
import {LoanLogicFixed} from "../contracts/loan/LoanLogicFixed.sol";
import {MembershipModule} from "../contracts/membership/MembershipModule.sol";

// 🧪 Mock Oracle for testing
contract MockOracle {
    function getLatestPrice() external pure returns (uint256) {
        return 1e18; // 1:1 mock price
    }
}

contract LoanManagerTest is Test {
    LoanManager loanManager;
    LoanCore loanCore;
    LoanLogicFixed loanLogic;
    MembershipModule membership;
    MockOracle oracle;

    address admin;
    address[] operators;

    function setUp() public {
        // Deploy dependencies
        membership = new MembershipModule();
        oracle = new MockOracle();
        loanCore = new LoanCore(address(membership));
        loanLogic = new LoanLogicFixed(
            address(loanCore),
            address(membership),
            address(oracle)
        );

        // Setup admin and operators
        admin = address(this);
        operators = new address[](1);
        operators[0] = admin;

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

    function testLoanManagerInitialized() public {
        assertTrue(address(loanManager) != address(0), "LoanManager should be deployed");
    }

    function testCreateLoan() public {
        address borrower = address(0xBEEF);
        address tokenAddress = address(0xCAFE);

        address[] memory guarantors = new address[](1);
        guarantors[0] = address(0xDEAD);

        uint256 loanId = loanManager.createLoan(
            borrower,
            LoanCore.PaymentType.Token,
            tokenAddress,
            1000 ether,
            30 days,
            guarantors
        );

        assertEq(loanId, 1, "Loan ID should be 1");
        assertEq(loanManager.getActiveLoanId(borrower), loanId, "Active loan should be set");
    }

    function testReduceLoanAmount() public {
        address borrower = address(0xBEEF);
        address tokenAddress = address(0xCAFE);

        address[] memory guarantors = new address[](1);
        guarantors[0] = address(0xDEAD);

        uint256 loanId = loanManager.createLoan(
            borrower,
            LoanCore.PaymentType.Token,
            tokenAddress,
            1000 ether,
            30 days,
            guarantors
        );

        loanLogic.reduceLoanAmount(loanId, 500 ether);

        (, , , uint256 loanAmount, , , , , ) = loanLogic.getLoanDetails(loanId);
        assertEq(loanAmount, 500 ether, "Loan amount should be reduced");
    }

function testUpdateLoanStatus() public {
    address borrower = address(0xBEEF);
    address tokenAddress = address(0xCAFE);

    address[] memory guarantors = new address[](1);
    guarantors[0] = address(0xDEAD);

    uint256 loanId = loanManager.createLoan(
        borrower,
        LoanCore.PaymentType.Token,
        tokenAddress,
        1000 ether,
        30 days,
        guarantors
    );

    loanLogic.updateLoanStatus(loanId, LoanCore.LoanStatus.FullyRepaid);

    uint256 rawStatus;
    (, , , , , , , rawStatus, ) = loanLogic.getLoanDetails(loanId);
    LoanCore.LoanStatus status = LoanCore.LoanStatus(rawStatus);

    assertEq(uint8(status), uint8(LoanCore.LoanStatus.FullyRepaid), "Loan status should be updated");
    assertEq(loanManager.getActiveLoanId(borrower), 0, "Active loan should be cleared");
}
}