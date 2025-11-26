// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./LoanTypes.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title LoanRegistry
/// @notice Tracks all loans by borrower, type, and status with real-time status updates
contract LoanRegistry is AccessControl {
    bytes32 public constant INDEXER_ROLE = keccak256("INDEXER_ROLE");

    struct LoanIndex {
        uint256 loanId;
        address borrower;
        LoanTypes.LoanType loanType;
        LoanTypes.LoanStatus status;
    }

    // ---------- Storage ----------
    mapping(uint256 => LoanIndex) public loanById;
    mapping(address => uint256[]) private _loansByBorrower;
    mapping(uint256 => uint256[]) private _loansByType;   // uint256 cast of LoanType
    mapping(uint256 => uint256[]) private _loansByStatus; // uint256 cast of LoanStatus

    // Tracks the index of a loan in the _loansByStatus array for O(1) removal
    mapping(uint256 => uint256) private _statusIndexInArray;

    // ---------- Events ----------
    event LoanIndexed(uint256 indexed loanId, address indexed borrower, LoanTypes.LoanType loanType, LoanTypes.LoanStatus status);
    event LoanStatusUpdated(uint256 indexed loanId, LoanTypes.LoanStatus oldStatus, LoanTypes.LoanStatus newStatus);

    // ---------- Constructor ----------
    constructor(address indexer) {
        require(indexer != address(0), "LoanRegistry: zero indexer");
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(INDEXER_ROLE, indexer);
    }

    // ---------- Functions ----------

    /// @notice Index a new loan
    function indexLoan(
        uint256 loanId,
        address borrower,
        LoanTypes.LoanType loanType,
        LoanTypes.LoanStatus status
    ) external onlyRole(INDEXER_ROLE) {
        require(borrower != address(0), "LoanRegistry: invalid borrower");
        require(loanById[loanId].loanId == 0, "LoanRegistry: loan already indexed");

        loanById[loanId] = LoanIndex(loanId, borrower, loanType, status);

        _loansByBorrower[borrower].push(loanId);
        _loansByType[uint256(loanType)].push(loanId);
        _statusIndexInArray[loanId] = _loansByStatus[uint256(status)].length;
        _loansByStatus[uint256(status)].push(loanId);

        emit LoanIndexed(loanId, borrower, loanType, status);
    }

    /// @notice Update the status of an existing loan
    function updateLoanStatus(uint256 loanId, LoanTypes.LoanStatus newStatus) external onlyRole(INDEXER_ROLE) {
        LoanIndex storage loan = loanById[loanId];
        require(loan.loanId != 0, "LoanRegistry: loan not found");

        LoanTypes.LoanStatus oldStatus = loan.status;
        if (oldStatus == newStatus) return; // no change

        // ---------- Remove from old status array ----------
        uint256 oldIndex = _statusIndexInArray[loanId];
        uint256[] storage oldArray = _loansByStatus[uint256(oldStatus)];
        uint256 lastLoanId = oldArray[oldArray.length - 1];

        // Swap with last element if not the same
        if (loanId != lastLoanId) {
            oldArray[oldIndex] = lastLoanId;
            _statusIndexInArray[lastLoanId] = oldIndex;
        }

        oldArray.pop(); // remove last
        // ---------- Add to new status array ----------
        _statusIndexInArray[loanId] = _loansByStatus[uint256(newStatus)].length;
        _loansByStatus[uint256(newStatus)].push(loanId);

        loan.status = newStatus;
        emit LoanStatusUpdated(loanId, oldStatus, newStatus);
    }

    /// @notice Get all loans of a borrower
    function getLoansByBorrower(address borrower) external view returns (uint256[] memory) {
        return _loansByBorrower[borrower];
    }

    /// @notice Get all loans of a given type
    function getLoansByType(LoanTypes.LoanType loanType) external view returns (uint256[] memory) {
        return _loansByType[uint256(loanType)];
    }

    /// @notice Get all loans of a given status
    function getLoansByStatus(LoanTypes.LoanStatus status) external view returns (uint256[] memory) {
        return _loansByStatus[uint256(status)];
    }
}
