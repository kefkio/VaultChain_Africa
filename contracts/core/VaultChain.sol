// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IMembershipModule} from "../core/interfaces/IMembershipModule.sol";
import {WalletManager} from "../treasury/WalletManager/WalletManager.sol";
import {LoanCore} from "../loan/LoanCore.sol";
import {Marketplace} from "../marketplace/Marketplace.sol";
import {OracleAggregator} from "../oracle/OracleAggregator.sol";
import {PoolVaultERC4626} from "../pool/PoolVaultERC4626.sol";
import {Treasury} from "../treasury/Treasury.sol";
import {TimelockController} from "../governance/TimelockController.sol";
import {LoanLogic} from "../loan/LoanLogic.sol";
import {LoanTypes} from "../loan/LoanTypes.sol";

/// @title VaultChain
/// @notice Central orchestrator connecting all modules
contract VaultChain {
    IMembershipModule public membershipModule;
    LoanCore public loanCore;
    LoanLogic public loanLogic;
    WalletManager public walletManager;
    Marketplace public marketplace;
    OracleAggregator public oracleAggregator;
    PoolVaultERC4626 public poolVault;
    Treasury public treasury;
    TimelockController public timelockController;

    event VaultChainDeployed(
        address membershipModule,
        address loanCore,
        address loanLogic,
        address walletManager,
        address marketplace,
        address oracleAggregator,
        address poolVault,
        address treasury,
        address timelockController
    );

    constructor(
        address _membershipModule,
        address _loanCore,
        address _loanLogic,
        address _walletManager,
        address _marketplace,
        address _oracleAggregator,
        address _poolVault,
        address _treasury,
        address _timelockController
    ) {
        require(_membershipModule != address(0), "Invalid MembershipModule");
        require(_loanCore != address(0), "Invalid LoanCore");
        require(_loanLogic != address(0), "Invalid LoanLogic");
        require(_walletManager != address(0), "Invalid WalletManager");
        require(_marketplace != address(0), "Invalid Marketplace");
        require(_oracleAggregator != address(0), "Invalid OracleAggregator");
        require(_poolVault != address(0), "Invalid PoolVault");
        require(_treasury != address(0), "Invalid Treasury");
        require(_timelockController != address(0), "Invalid TimelockController");

        membershipModule = IMembershipModule(_membershipModule);
        loanCore = LoanCore(_loanCore);
        loanLogic = LoanLogic(_loanLogic);
        walletManager = WalletManager(_walletManager);
        marketplace = Marketplace(_marketplace);
        oracleAggregator = OracleAggregator(_oracleAggregator);
        poolVault = PoolVaultERC4626(_poolVault);
        treasury = Treasury(_treasury);
        timelockController = TimelockController(_timelockController);

        emit VaultChainDeployed(
            _membershipModule,
            _loanCore,
            _loanLogic,
            _walletManager,
            _marketplace,
            _oracleAggregator,
            _poolVault,
            _treasury,
            _timelockController
        );
    }

    // ---------- Helper read functions ----------

    function getMemberWallet(address user) external view returns (address) {
        return membershipModule.getMemberWallet(user);
    }

    function isMember(address user) external view returns (bool) {
        return membershipModule.isMember(user);
    }

    /// @notice Get the status of a loan
    function getLoanStatus(uint256 loanId) external view returns (LoanTypes.LoanStatus) {
        (, , , , , , , , LoanTypes.LoanStatus status) = loanLogic.getLoanDetails(loanId);
        return status;
    }

    function getWalletChangeRequest(uint256 requestId)
        external
        view
        returns (
            address member,
            address proposedWallet,
            uint256 approvals,
            bool executed
        )
    {
        return walletManager.getWalletChangeRequest(requestId);
    }

    function hasApprovedWalletChange(uint256 requestId, address approver) external view returns (bool) {
        return walletManager.hasApproved(requestId, approver);
    }
}
