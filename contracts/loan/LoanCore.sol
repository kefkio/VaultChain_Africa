// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;


import "../core/interfaces/IMembershipModule.sol";


contract LoanCore {
    IMembershipModule public membership;

    constructor(address _membership) {
        require(_membership != address(0), "Invalid membership");
        membership = IMembershipModule(_membership);
    }

    // -----------------------------
    // Enums
    // -----------------------------
    enum KycStatus { Pending, Verified, Rejected }
    enum PaymentType { Native, Fiat, Token }
    enum LoanStatus {
        Requested,
        Guaranteed,
        Approved,
        Disbursed,
        PartiallyRepaid,
        FullyRepaid,
        Repaid,
        Defaulted
    }

    // -----------------------------
    // Structs
    // -----------------------------
    struct Loan {
        address borrower;
        PaymentType paymentType;
        address tokenAddress;
        uint256 loan_amount;
        uint256 interestRate;
        uint256 duration;
        uint256 dueDate;
        LoanStatus status;
        address[] guarantors;
    }

    // -----------------------------
    // Storage
    // -----------------------------
    uint256 public loanCounter;
    mapping(uint256 => Loan) internal loans;
    mapping(address => uint256) internal activeLoanId;

    // -----------------------------
    // Events
    // -----------------------------
    event LoanCreated(uint256 indexed loanId, address borrower, uint256 amount);

    // -----------------------------
    // Core Storage Functions
    // -----------------------------

    function createLoan(
        address borrower,
        PaymentType paymentType,
        address tokenAddress,
        uint256 amount,
        uint256 duration,
        address[] memory guarantors
    ) external returns (uint256) {
        require(amount > 0, "LoanCore: invalid amount");
        require(duration > 0, "LoanCore: invalid duration");
        require(activeLoan(borrower) == 0, "LoanCore: active loan exists");

        loanCounter++;
        uint256 loanId = loanCounter;

        Loan storage loan = loans[loanId];
        loan.borrower = borrower;
        loan.paymentType = paymentType;
        loan.tokenAddress = tokenAddress;
        loan.loan_amount = amount;
        loan.duration = duration;
        loan.dueDate = block.timestamp + duration;
        loan.status = LoanStatus.Requested;
        loan.guarantors = guarantors;

        activeLoanId[borrower] = loanId;

        emit LoanCreated(loanId, borrower, amount);
        return loanId;
    }
    

    function getLoan(uint256 loanId) external view returns (Loan memory) {
        return loans[loanId];
    }
        function reduceLoanAmount(uint256 loanId, uint256 amount) external {
        Loan storage loan = loans[loanId];
        require(amount <= loan.loan_amount, "LoanCore: amount exceeds loan balance");
        loan.loan_amount -= amount;
        if (loan.loan_amount == 0 && loan.status == LoanStatus.Disbursed) {
            loan.status = LoanStatus.FullyRepaid;
        }
    }

    function updateLoanStatus(uint256 loanId, LoanStatus newStatus) external {
        loans[loanId].status = newStatus;
        if (
            newStatus == LoanStatus.FullyRepaid || 
            newStatus == LoanStatus.Defaulted
        ) {
            activeLoanId[loans[loanId].borrower] = 0;
        }
    }

    function activeLoan(address borrower) public view returns (uint256) {
        return activeLoanId[borrower];
    }
}
