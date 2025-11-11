# VaultChain Loan Module

## Overview

The **VaultChain Loan Module** is a modular smart contract system that manages the full lifecycle of loans in the VaultChain ecosystem.  
It is designed with separation of concerns in mind, dividing responsibilities into **storage**, **logic**, and **disbursement** modules for easier maintenance, upgradeability, and security.

The system integrates with the **Membership module** to validate member eligibility, KYC status, and approved wallets for fund disbursement.

---

## Module Architecture

### 1. LoanCore.sol
- **Purpose:** Core storage of loans and member loan data.
- **Responsibilities:**
  - Store loan details (`Loan` struct).
  - Track active loans, KYC, and guarantor usage.
  - Provide getters and internal setters for loans:
    - `getLoan()`
    - `updateLoan()`
    - `updateLoanStatus()`
    - `reduceLoanAmount()`
- **Integration:** References the `IMembershipModule` to verify member wallets and KYC.

### 2. LoanLogicFixed.sol
- **Purpose:** Handles **loan lifecycle operations** and business logic.
- **Responsibilities:**
  - Request loans.
  - Approve loans (operator role only).
  - Disburse loans via approved wallets (native or ERC20 tokens).
  - Accept repayments and update loan status (`PartiallyRepaid`, `FullyRepaid`).
  - Mark loans as defaulted.
- **Integration:** Calls `LoanCore` for storage operations and `IMembershipModule` to validate members and wallets.

### 3. LoanDisburser.sol
- **Purpose:** Handles **secure loan disbursement** and repayments.
- **Responsibilities:**
  - Transfer funds to borrower wallets upon loan approval.
  - Process repayments (native or token payments).
  - Update loan status after repayment or default.
- **Integration:** Reads/writes from `LoanCore` and uses `IMembershipModule` to ensure disbursements go to approved wallets.

### 4. Integration with Membership Module
- Loan modules rely on `MembershipModule` to:
  - Check if a borrower is a registered member (`isMember`).
  - Retrieve the member’s approved wallet (`getMemberWallet`).
  - Verify KYC status and active membership.

---

## Key Features

- **Role-based access control:** Operators can approve and disburse loans; admins manage operators.
- **Multi-payment support:** Supports `Native` (ETH) and `Token` (ERC20) payments.
- **Loan lifecycle management:**  
  Requested → Approved → Disbursed → PartiallyRepaid → FullyRepaid / Defaulted
- **Secure disbursement:** Loans are disbursed only to approved wallets stored in the Membership module.
- **Upgradeable architecture:** Logic and storage separation allows for modular upgrades without affecting stored loan data.

---

## Example Flow

1. **Member requests a loan** via `LoanLogicFixed.requestLoan()`  
   - Validates membership, KYC, and no active loans.
   - Stores loan in `LoanCore`.

2. **Operator approves the loan** via `LoanLogicFixed.approveLoan()`.

3. **Operator disburses the loan** via `LoanDisburser.disburseLoan()`  
   - Funds are sent to the member’s approved wallet.

4. **Member repays loan** via `LoanDisburser.repayLoan()`  
   - Updates loan balance.
   - Changes loan status to `PartiallyRepaid` or `FullyRepaid`.

5. **Mark defaulted loans** using `LoanDisburser.markDefault()` if overdue.

---

## Events

| Event | Description |
|-------|-------------|
| `LoanRequested` | Emitted when a loan is requested. |
| `LoanApproved` | Emitted when a loan is approved by an operator. |
| `LoanDisbursed` | Emitted when a loan is disbursed to the borrower. |
| `LoanRepaid` | Emitted when a repayment is made. |
| `LoanDefaulted` | Emitted when a loan is marked as defaulted. |
| `MemberRegistered` | Emitted when a member is registered in LoanCore. |
| `KycUpdated` | Emitted when a member's KYC status is updated. |

---

## Access Control

- **DEFAULT_ADMIN_ROLE:** Admins that can grant/revoke roles and manage operators.  
- **OPERATOR_ROLE:** Authorized to approve, disburse, and manage loans.  

---

## Deployment Notes

1. Deploy `MembershipModule` first.
2. Deploy `LoanCore` with `MembershipModule` address.
3. Deploy `LoanLogicFixed` with `LoanCore` and `MembershipModule` addresses.
4. Deploy `LoanDisburser` with `LoanCore` and `MembershipModule` addresses.
5. Grant `OPERATOR_ROLE` to trusted operator addresses in logic/disburser modules.

---

## Security Considerations

- **Wallet verification:** Disbursement always uses the wallet retrieved from `MembershipModule`.
- **NonReentrant:** `LoanDisburser.repayLoan()` protects against reentrancy attacks.
- **Role-based operations:** Only authorized roles can approve, disburse, or mark defaults.

---

## Next Steps / Recommendations

- Consider integrating **interest calculation** and repayment schedules.
- Add **on-chain loan analytics** for risk assessment.
- Implement **multi-guarantor validation** in `LoanLogicFixed`.
- Integrate with **VaultChain core** for cross-module operations.


---

## Developer Quickstart

This section provides example interactions with the VaultChain Loan modules for developers.

### 1. Prerequisites

- Installed Ethereum development environment (Hardhat / Foundry / Remix)
- Deployed `MembershipModule`, `LoanCore`, `LoanLogicFixed`, and `LoanDisburser`
- Operator addresses granted `OPERATOR_ROLE`
- Member addresses registered and KYC verified

---

### 2. Request a Loan

```solidity
// Borrower calls this function
uint256 loanAmount = 1 ether;
LoanCore.PaymentType paymentType = LoanCore.PaymentType.Native;
address tokenAddress = address(0); // not used for native
uint256 duration = 30 days;
address ;
guarantors[0] = 0xGuarantor1;
guarantors[1] = 0xGuarantor2;

uint256 loanId = loanLogic.requestLoan(
    loanAmount,
    paymentType,
    tokenAddress,
    guarantors.length,
    duration,
    guarantors
);

3. Approve a Loan (Operator Role)

// Operator approves the loan
loanLogic.approveLoan(loanId);


4. Disburse Loan (Operator Role)

// Operator disburses loan to approved wallet
loanDisburser.disburseLoan(loanId);
// Operator disburses loan to approved wallet
loanDisburser.disburseLoan(loanId);

For Native payments, ETH is sent to the member’s approved wallet.

For Token payments, ERC20 tokens are transferred.

5. Repay Loan

// Borrower repays a portion or full loan
uint256 repaymentAmount = 0.5 ether; // can be full or partial
loanDisburser.repayLoan{value: repaymentAmount}(loanId, repaymentAmount);
LoanStatus automatically updates:

PartiallyRepaid if remaining balance > 0

FullyRepaid if remaining balance = 0

6. Mark Defaulted Loan (Operator Role)

// Operator marks a loan as defaulted if overdue
loanDisburser.markDefault(loanId);

Loan status changes to Defaulted if past dueDate and not fully repaid.

7. Query Loan Details

(
    address borrower,
    LoanCore.PaymentType paymentType,
    address tokenAddress,
    uint256 guarantorCount,
    uint256 amount,
    uint256 interestRate,
    uint256 duration,
    uint256 dueDate,
    LoanCore.LoanStatus status
) = loanLogic.getLoanDetails(loanId);

Retrieve all relevant loan information for frontend or analytics.

8. Notes for Developers

Always verify KYC status before approving or disbursing loans.

Ensure borrower wallets are correct and retrieved via MembershipModule.

LoanCore storage module separates state from logic for easier upgrades.

Use AccessControl roles to enforce operator/admin permissions.

# VaultChain Loans Module Architecture

```mermaid
flowchart TD
    MembershipModule[MembershipModule]
    LoanCore[LoanCore]
    LoanLogicFixed[LoanLogicFixed]
    LoanDisburser[LoanDisburser]
    WalletManager[WalletManager]

    MembershipModule -->|getMemberWallet / isMember| LoanLogicFixed
    MembershipModule -->|getMemberWallet / isMember| LoanDisburser
    MembershipModule -->|updateMemberWallet| WalletManager

    LoanLogicFixed -->|read/write loans| LoanCore
    LoanDisburser -->|read/write loans| LoanCore
