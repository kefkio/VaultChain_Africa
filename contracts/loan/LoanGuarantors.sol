// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./LoanTypes.sol";
import "./LoanCore.sol";
import "./CollateralVault.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title LoanGuarantors
/// @notice Manages guarantor nomination, acceptance, collateral locking, release, and liquidation
contract LoanGuarantors is ReentrancyGuard {
    using LoanTypes for *;

    // ---------- Enums ----------
    enum GuarantorType { External, Self }

    // ---------- Structs ----------
    struct GuarantorInfo {
        address guarantor;
        GuarantorType gType;
        bool accepted;
    }

    struct GuarantorCollateral {
        address guarantor;
        address asset;
        uint256 tokenIdOrAmount;
        LoanTypes.CollateralType cType;
        LoanTypes.CollateralState state;
        uint256 valueAtLock;
    }

    // ---------- State ----------
    LoanCore public immutable loanCore;
    CollateralVault public immutable collateralVault;

    // List of guarantors per loan
    mapping(uint256 => GuarantorInfo[]) internal guarantorsByLoan;

    // loanId => collateralId => collateral info
    mapping(uint256 => mapping(uint256 => GuarantorCollateral)) public collaterals;

    // bookkeeping
    mapping(address => mapping(address => uint256[])) public collateralRecords;
    mapping(uint256 => address[]) private _guarantorList;
    mapping(uint256 => uint256[]) private _collateralIds;

    // ---------- Events ----------
    event GuarantorAdded(uint256 indexed loanId, address indexed guarantor, GuarantorType gType);
    event GuarantorAccepted(uint256 indexed loanId, address indexed guarantor, GuarantorType gType);
    event GuarantorCollateralLocked(
        uint256 indexed loanId,
        uint256 indexed collateralId,
        address indexed guarantor,
        GuarantorType gType,
        address asset,
        uint256 tokenIdOrAmount,
        uint256 collateralValue
    );
    event GuarantorCollateralReleased(uint256 indexed loanId, uint256 indexed collateralId, address indexed guarantor);
    event GuarantorCollateralLiquidated(
        uint256 indexed loanId,
        uint256 indexed collateralId,
        address indexed guarantor,
        address recipient,
        uint256 valueAtLock
    );
    event GuarantorRemoved(uint256 indexed loanId, address indexed guarantor);

    // ---------- Constructor ----------
    constructor(address _loanCore, address _collateralVault) {
        require(_loanCore != address(0), "LoanGuarantors: loanCore is zero");
        require(_collateralVault != address(0), "LoanGuarantors: vault is zero");

        loanCore = LoanCore(_loanCore);
        collateralVault = CollateralVault(_collateralVault);
    }

    // ---------- Guarantor setup ----------

    /// @notice Borrower nominates a guarantor (can be self or external)
    function addGuarantor(uint256 loanId, address guarantor) external {
        address borrower = loanCore.getBorrower(loanId);
        require(msg.sender == borrower, "Only borrower can add guarantor");
        require(guarantor != address(0), "Guarantor is zero address");

        // 1. Ensure guarantor not already added
        GuarantorInfo[] storage list = guarantorsByLoan[loanId];
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i].guarantor == guarantor) {
                revert("Guarantor already added");
            }
        }

        // 2. Classify type
        GuarantorType gType = guarantor == borrower ? GuarantorType.Self : GuarantorType.External;

        // 3. Push new guarantor
        list.push(
            GuarantorInfo({
                guarantor: guarantor,
                gType: gType,
                accepted: false
            })
        );

        _guarantorList[loanId].push(guarantor);

        emit GuarantorAdded(loanId, guarantor, gType);
    }

    /// @notice Guarantor (or borrower if self-guarantor) accepts the role
    function acceptGuarantorRole(uint256 loanId) external {
        GuarantorInfo[] storage list = guarantorsByLoan[loanId];
        uint256 idx = type(uint256).max;
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i].guarantor == msg.sender) {
                idx = i;
                break;
            }
        }

        require(idx != type(uint256).max, "Not nominated");

        GuarantorInfo storage info = list[idx];
        require(!info.accepted, "Already accepted");

        if (info.gType == GuarantorType.Self) {
            address borrower = loanCore.getBorrower(loanId);
            require(msg.sender == borrower, "Only borrower can self-guarantee");
        }

        info.accepted = true;
        emit GuarantorAccepted(loanId, msg.sender, info.gType);
    }

    // ---------- Collateral locking ----------
    // Your existing lock / release / liquidate logic can stay mostly unchanged,
    // just make sure it uses guarantorsByLoan / GuarantorCollateral consistently.

    // ---------- Views ----------

    function getGuarantorInfo(uint256 loanId, address guarantor)
        external
        view
        returns (GuarantorInfo memory)
    {
        GuarantorInfo[] storage list = guarantorsByLoan[loanId];
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i].guarantor == guarantor) {
                return list[i];
            }
        }
        // default "empty" response
        return GuarantorInfo({
            guarantor: address(0),
            gType: GuarantorType.External,
            accepted: false
        });
    }

    function getCollateral(uint256 loanId, uint256 collateralId)
        external
        view
        returns (GuarantorCollateral memory)
    {
        return collaterals[loanId][collateralId];
    }

    function listGuarantors(uint256 loanId) external view returns (address[] memory) {
        return _guarantorList[loanId];
    }

    function listCollateralIds(uint256 loanId) external view returns (uint256[] memory) {
        return _collateralIds[loanId];
    }

    function guarantorHasLockedCollateral(uint256 loanId, address guarantor) external view returns (bool) {
        uint256[] memory ids = _collateralIds[loanId];
        for (uint256 i = 0; i < ids.length; i++) {
            GuarantorCollateral storage col = collaterals[loanId][ids[i]];
            if (col.guarantor == guarantor && col.state == LoanTypes.CollateralState.Locked) {
                return true;
            }
        }
        return false;
    }

    /// @notice Number of guarantors nominated for a loan
    function getGuarantorCount(uint256 loanId) external view returns (uint256) {
        return _guarantorList[loanId].length;
    }
}
