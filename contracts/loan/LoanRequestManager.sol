// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./LoanCore.sol";
import "./LoanGuarantors.sol";
import "../core/interfaces/IMembershipModule.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./LoanTypes.sol";

contract LoanRequestManager is AccessControl {
    using LoanTypes for *;

    // ---------- State ----------
    LoanCore public loanCore;
    LoanGuarantors public loanGuarantors;
    IMembershipModule public membership;

    mapping(address => bool) private _registered;
    mapping(address => LoanTypes.KycStatus) private _kyc;

    // Extra loan metadata
    mapping(uint256 => LoanTypes.PaymentType) private _paymentType;
    mapping(uint256 => address) private _tokenAddress;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // ---------- Events ----------
    event MemberRegistered(address member);
    event KycUpdated(address member, LoanTypes.KycStatus status);
    event LoanRequested(uint256 loanId, address borrower);

    // ---------- Constructor ----------
    constructor(
        address loanCoreAddress,
        address loanGuarantorsAddress,
        address membershipContract
    ) {
        loanCore = LoanCore(loanCoreAddress);
        loanGuarantors = LoanGuarantors(loanGuarantorsAddress);
        membership = IMembershipModule(membershipContract);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    // ---------- Member Functions ----------
    function registerMember() external {
        require(!_registered[msg.sender], "Already registered");
        _registered[msg.sender] = true;
        _kyc[msg.sender] = LoanTypes.KycStatus.Pending;
        emit MemberRegistered(msg.sender);
    }

    function updateKyc(address member, LoanTypes.KycStatus status)
        external
        onlyRole(OPERATOR_ROLE)
    {
        require(_registered[member], "Not registered");
        _kyc[member] = status;
        emit KycUpdated(member, status);
    }

    // ---------- Loan Request ----------
    function requestLoan(
        uint256 amount,
        uint256 duration,
        uint256 interestRate,
        uint256 borrowerCollateralAmount,
        address borrowerCollateralToken,
        LoanTypes.PaymentType paymentType,
        address tokenAddress,
        address[] memory guarantors
    ) external returns (uint256) {
        require(_registered[msg.sender], "Not registered");
        require(_kyc[msg.sender] == LoanTypes.KycStatus.Verified, "KYC not verified");
        require(membership.isMember(msg.sender), "Not a member");

        // 1️⃣ Create the core loan in LoanCore
        uint256 loanId = loanCore.createLoan(
            msg.sender,
            amount,
            duration,
            interestRate,
            borrowerCollateralAmount,
            borrowerCollateralToken,
            paymentType,
            tokenAddress,
            LoanTypes.LoanType.Personal
        );

        // 2️⃣ Store extra metadata
        _paymentType[loanId] = paymentType;
        _tokenAddress[loanId] = tokenAddress;

        // 3️⃣ Add guarantors
        for (uint256 i = 0; i < guarantors.length; i++) {
            loanGuarantors.addGuarantor(loanId, guarantors[i]);
        }

        emit LoanRequested(loanId, msg.sender);
        return loanId;
    }

    // ---------- View functions ----------
    function getKycStatus(address member) external view returns (LoanTypes.KycStatus) {
        return _kyc[member];
    }

    function getLoanPaymentType(uint256 loanId) external view returns (LoanTypes.PaymentType) {
        return _paymentType[loanId];
    }

    function getLoanTokenAddress(uint256 loanId) external view returns (address) {
        return _tokenAddress[loanId];
    }
}