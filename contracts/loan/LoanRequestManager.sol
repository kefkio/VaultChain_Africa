// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./LoanCore.sol";
import "../core/interfaces/IMembershipModule.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract LoanRequestManager is AccessControl {
    LoanCore public loanCore;
    IMembershipModule public membership;

    enum KycStatus { Pending, Verified, Rejected }

    mapping(address => bool) private _registered;
    mapping(address => KycStatus) private _kyc;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // ---------- Events ----------
    event MemberRegistered(address member);
    event KycUpdated(address member, KycStatus status);
    event LoanRequested(uint256 loanId, address borrower);

    constructor(address loanCoreAddress, address membershipContract) {
        loanCore = LoanCore(loanCoreAddress);
        membership = IMembershipModule(membershipContract);
    }

    // ---------- Member Functions ----------
    function registerMember() external {
        require(!_registered[msg.sender], "Already registered");
        _registered[msg.sender] = true;
        _kyc[msg.sender] = KycStatus.Pending;
        emit MemberRegistered(msg.sender);
    }

    function updateKyc(address member, KycStatus status) external onlyRole(OPERATOR_ROLE) {
        require(_registered[member], "Not registered");
        _kyc[member] = status;
        emit KycUpdated(member, status);
    }

    // ---------- Loan Request ----------
    function requestLoan(
        uint256 amount,
        LoanCore.PaymentType paymentType,
        address tokenAddress,
        uint256 duration,
        address[] memory guarantors
    ) external returns (uint256) {
        require(_registered[msg.sender], "Not registered");
        require(_kyc[msg.sender] == KycStatus.Verified, "KYC not verified");
        require(membership.isMember(msg.sender), "Not a member");

        LoanCore.Loan memory loanStruct = LoanCore.Loan({
            borrower: msg.sender,
            paymentType: paymentType,
            tokenAddress: tokenAddress,
            loan_amount: amount,
            interestRate: 0,
            duration: duration,
            dueDate: block.timestamp + duration,
            status: LoanCore.LoanStatus.Requested,
            guarantors: guarantors
        });

        uint256 loanId = loanCore.createLoan(msg.sender, paymentType, tokenAddress, amount, duration, guarantors);
        emit LoanRequested(loanId, msg.sender);
        return loanId;
    }
}
