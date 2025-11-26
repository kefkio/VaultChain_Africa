// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;



library LoanTypes {
    // ---------- Core Enums ----------
    enum LoanType {
        Personal,
        Business,
        Agricultural,
        Education,
        Mortgage,
        AssetBacked,
        InvoiceFinancing,
        MicroLoan,
        GroupLoan,
        Emergency,
        GreenLoan
    }

    enum PaymentType {
        Native,
        Fiat,
        Token,
        EqualInstallments,
        Bullet,
        InterestOnly,
        Amortizing
    }

    enum CollateralType {
        ERC20,
        ERC721,
        ERC1155,
        Native
    }

    enum LoanStatus {
        Requested,
        Guaranteed,
        Approved,
        Disbursed,
        PartiallyRepaid,
        FullyRepaid,
        Watch,
        UnderWatch,
        Performing,
        Defaulted,
        AwaitingCollateral,
        AwaitingFunding,
        Active
    }

    enum KycStatus {
        None,
        Pending,
        Verified,
        Rejected
    }

    enum CollateralState {
        None,
        PendingGuarantor,
        AcceptedNoCollateral,
        Locked,
        Released,
        Liquidated
    }

    enum GuarantorType {
        External,
        Self
    }

    // ---------- Structs ----------
    struct LoanProfile {
        LoanType loanType;
        PaymentType paymentType;
        CollateralType collateralType;
    }

struct Loan {
    address borrower;
    uint256 amount;
    uint256 duration;
    uint256 interestRate;
    uint256 borrowerCollateralAmount;
    address borrowerCollateralToken;
    LoanProfile profile;
    address tokenAddress;
    LoanStatus status;
    uint256 dueDate;
    uint256 lastInterestUpdate;
    uint256 interestRateBps;
    uint256 repaidAmount;
    uint256 totalInterestAccrued;
    uint256 createdAt;
    uint256 updatedAt;
    bool exists;
    address[] guarantors; // <--- add here
}

    struct GuarantorInfo {
        address guarantor;
        GuarantorType gType;
        bool accepted;
        // Extendable: collateral amount, token, etc.
    }

    // ---------- Helpers ----------
    function loanTypeToString(LoanType l) internal pure returns (string memory) {
        if (l == LoanType.Personal) return "Personal";
        if (l == LoanType.Business) return "Business";
        if (l == LoanType.Agricultural) return "Agricultural";
        if (l == LoanType.Education) return "Education";
        if (l == LoanType.Mortgage) return "Mortgage";
        if (l == LoanType.AssetBacked) return "AssetBacked";
        if (l == LoanType.InvoiceFinancing) return "InvoiceFinancing";
        if (l == LoanType.MicroLoan) return "MicroLoan";
        if (l == LoanType.GroupLoan) return "GroupLoan";
        if (l == LoanType.Emergency) return "Emergency";
        if (l == LoanType.GreenLoan) return "GreenLoan";
        return "Unknown";
    }

    function paymentTypeToString(PaymentType p) internal pure returns (string memory) {
        if (p == PaymentType.Native) return "Native";
        if (p == PaymentType.Fiat) return "Fiat";
        if (p == PaymentType.Token) return "Token";
        if (p == PaymentType.EqualInstallments) return "EqualInstallments";
        if (p == PaymentType.Bullet) return "Bullet";
        if (p == PaymentType.InterestOnly) return "InterestOnly";
        if (p == PaymentType.Amortizing) return "Amortizing";
        return "Unknown";
    }

    function loanStatusToString(LoanStatus s) internal pure returns (string memory) {
        if (s == LoanStatus.Requested) return "Requested";
        if (s == LoanStatus.Guaranteed) return "Guaranteed";
        if (s == LoanStatus.Approved) return "Approved";
        if (s == LoanStatus.Disbursed) return "Disbursed";
        if (s == LoanStatus.PartiallyRepaid) return "PartiallyRepaid";
        if (s == LoanStatus.FullyRepaid) return "FullyRepaid";
        if (s == LoanStatus.Watch) return "Watch";
        if (s == LoanStatus.UnderWatch) return "UnderWatch";
        if (s == LoanStatus.Performing) return "Performing";
        if (s == LoanStatus.Defaulted) return "Defaulted";
        return "Unknown";
    }
}