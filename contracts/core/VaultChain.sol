// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Import interfaces and modules
import {IMembershipModule} from "../core/interfaces/IMembershipModule.sol";
import {WalletManager} from "../WalletManager/WalletManager.sol";
import {LoanLogicFixed} from "../loan/LoanLogicFixed.sol";
import {LoanCore} from "../loan/LoanCore.sol";
import {Marketplace} from "../marketplace/Marketplace.sol";
import {OracleAggregator} from "../oracle/OracleAggregator.sol";
import {PoolVaultERC4626} from "../pool/PoolVaultERC4626.sol";
import {Treasury} from "../treasury/Treasury.sol";
import {TimelockController} from "../governance/TimelockController.sol";

/// @title VaultChain - Modular DeFi / Core orchestrator
/// @notice Central contract that connects all modules
contract VaultChain {
    // --- Core modules ---
    IMembershipModule public membershipModule;
    LoanCore public loanCore;
    LoanLogicFixed public loanLogic;
    WalletManager public walletManager;
    Marketplace public marketplace;
    OracleAggregator public oracleAggregator;
    PoolVaultERC4626 public poolVault;
    Treasury public treasury;
    TimelockController public timelockController;

    /// @notice Event emitted on deployment
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

    /// @param _membershipModule Address of the MembershipModule
    /// @param _loanCore Address of the LoanCore storage module
    /// @param _loanLogic Address of the LoanLogicFixed module (payable)
    /// @param _walletManager Address of the WalletManager module
    /// @param _marketplace Address of the Marketplace module
    /// @param _oracleAggregator Address of the OracleAggregator module
    /// @param _poolVault Address of the PoolVaultERC4626 module
    /// @param _treasury Address of the Treasury module
    /// @param _timelockController Address of the TimelockController module
    constructor(
        address _membershipModule,
        address _loanCore,
        address payable _loanLogic,
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
        loanLogic = LoanLogicFixed(_loanLogic);
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

    // --- Helper read functions ---

    function getMemberWallet(address user) external view returns (address) {
        return membershipModule.getMemberWallet(user);
    }

    function isMember(address user) external view returns (bool) {
        return membershipModule.isMember(user);
    }

    function getLoanStatus(uint256 loanId) external view returns (LoanCore.LoanStatus) {
        (, , , , , , , , LoanCore.LoanStatus status) = loanLogic.getLoanDetails(loanId);
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