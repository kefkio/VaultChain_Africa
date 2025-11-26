// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./LoanTypes.sol";
import "./LoanCore.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";



/// @title CollateralVault
/// @notice Manages collateral locking, releasing, and liquidation for loans
contract CollateralVault is ReentrancyGuard{
    using LoanTypes for *;
    using SafeERC20 for IERC20;

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
    address public loanGuarantors;

    // loanId => collateralId => collateral record
    mapping(uint256 => mapping(uint256 => GuarantorCollateral)) public collaterals;
    mapping(uint256 => uint256) private _loanCollateralCounters;
    mapping(address => mapping(address => uint256[])) public collateralRecords;




    // ---------- Events ----------
    event CollateralLocked(
        uint256 indexed loanId,
        uint256 indexed collateralId,
        address indexed guarantor,
        address asset,
        uint256 tokenIdOrAmount,
        uint256 valueAtLock
    );

    event CollateralReleased(
        uint256 indexed loanId,
        uint256 indexed collateralId,
        address indexed guarantor
    );

    event CollateralLiquidated(
        uint256 indexed loanId,
        uint256 indexed collateralId,
        address indexed guarantor
    );

    // ---------- Modifiers ----------
    modifier onlyLoanGuarantors() {
        require(msg.sender == loanGuarantors, "CollateralVault: Only LoanGuarantors");
        _;
    }

    modifier onlyLoanGuarantorsOrCore() {
        require(msg.sender == loanGuarantors || msg.sender == address(loanCore), "CollateralVault: Not authorized");
        _;
    }

    // ---------- Constructor ----------
    constructor(address _loanCore) {
        loanCore = LoanCore(_loanCore);
    }

    function setLoanGuarantors(address _loanGuarantors) external {
        require(loanGuarantors == address(0), "CollateralVault: Already set");
        loanGuarantors = _loanGuarantors;
    }

    function _nextCollateralId(uint256 loanId) internal returns (uint256) {
    _loanCollateralCounters[loanId] += 1;
    return _loanCollateralCounters[loanId];
}

    // ---------- Collateral Operations ----------
function lockCollateral(
    uint256 loanId,
    address guarantor,
    address asset,
    uint256 tokenIdOrAmount,
    LoanTypes.CollateralType cType
) external onlyLoanGuarantors nonReentrant returns (uint256 collateralValue, uint256 collateralId) {
    collateralId = _nextCollateralId(loanId);
    collateralValue = _getCollateralValue(asset, tokenIdOrAmount, cType);

    collaterals[loanId][collateralId] = GuarantorCollateral({
        guarantor: guarantor,
        asset: asset,
        tokenIdOrAmount: tokenIdOrAmount,
        cType: cType,
        state: LoanTypes.CollateralState.Locked,
        valueAtLock: collateralValue
    });

    _pullAssetFrom(guarantor, asset, tokenIdOrAmount, cType);

    emit CollateralLocked(loanId, collateralId, guarantor, asset, tokenIdOrAmount, collateralValue);
}


function releaseCollateral(uint256 loanId, uint256 collateralId) external onlyLoanGuarantorsOrCore nonReentrant {
    LoanTypes.LoanStatus status = loanCore.getLoanStatus(loanId);
    require(status == LoanTypes.LoanStatus.FullyRepaid, "CollateralVault: Loan not fully repaid");

    GuarantorCollateral storage col = collaterals[loanId][collateralId];
    require(col.state == LoanTypes.CollateralState.Locked, "CollateralVault: Not locked");

    // Effects before interactions
    col.state = LoanTypes.CollateralState.Released;
    _transferAssetTo(col.guarantor, col.asset, col.tokenIdOrAmount, col.cType);

    emit CollateralReleased(loanId, collateralId, col.guarantor);
}

function liquidateCollateral(uint256 loanId, uint256 collateralId, address recipient) external onlyLoanGuarantorsOrCore nonReentrant {
    LoanTypes.LoanStatus status = loanCore.getLoanStatus(loanId);
    require(status == LoanTypes.LoanStatus.Defaulted, "CollateralVault: Loan not defaulted");

    GuarantorCollateral storage col = collaterals[loanId][collateralId];
    require(col.state == LoanTypes.CollateralState.Locked, "CollateralVault: Not locked");

    col.state = LoanTypes.CollateralState.Liquidated;
    _transferAssetTo(recipient, col.asset, col.tokenIdOrAmount, col.cType); // fix recipient usage

    emit CollateralLiquidated(loanId, collateralId, col.guarantor);
}



    // ---------- Internal Helpers ----------
function _pullAssetFrom(
    address from,
    address asset,
    uint256 tokenIdOrAmount,
    LoanTypes.CollateralType cType
) internal {
    // Checks
    require(cType != LoanTypes.CollateralType.Native, "Native assets handled separately");
    
    // Effects (all state updates)
    uint256 collateralId = _nextCollateralId(0); // Use 0 as dummy loanId for tracking
    collaterals[0][collateralId] = GuarantorCollateral({
        guarantor: from,
        asset: asset,
        tokenIdOrAmount: tokenIdOrAmount,
        cType: cType,
        state: LoanTypes.CollateralState.Locked,
        valueAtLock: 0 // Will be updated later
    });
    collateralRecords[from][asset].push(tokenIdOrAmount);
    
    // Interactions
    if (cType == LoanTypes.CollateralType.ERC20) {
        IERC20(asset).safeTransferFrom(from, address(this), tokenIdOrAmount);
    } else if (cType == LoanTypes.CollateralType.ERC721) {
        IERC721(asset).safeTransferFrom(from, address(this), tokenIdOrAmount);
    } else if (cType == LoanTypes.CollateralType.ERC1155) {
        IERC1155(asset).safeTransferFrom(from, address(this), tokenIdOrAmount, 1, "");
    }
}

function _transferAssetTo(
    address to,
    address asset,
    uint256 tokenIdOrAmount,
    LoanTypes.CollateralType cType
) internal {
    if (cType == LoanTypes.CollateralType.ERC20) {
        IERC20(asset).safeTransfer(to, tokenIdOrAmount);
    } else if (cType == LoanTypes.CollateralType.ERC721) {
        IERC721(asset).safeTransferFrom(address(this), to, tokenIdOrAmount);
    } else if (cType == LoanTypes.CollateralType.ERC1155) {
        IERC1155(asset).safeTransferFrom(address(this), to, tokenIdOrAmount, 1, "");
    } else if (cType == LoanTypes.CollateralType.Native) {
        (bool sent, ) = payable(to).call{value: tokenIdOrAmount}("");
        require(sent, "CollateralVault: Native transfer failed");
    } else {
        revert("CollateralVault: Unsupported collateral type");
    }
}

    function _getCollateralValue(
        address /*asset*/,
        uint256 /*tokenIdOrAmount*/,
        LoanTypes.CollateralType /*cType*/
    ) internal pure returns (uint256) {
        return 0; // TODO: implement oracle or pricing logic
    }
}