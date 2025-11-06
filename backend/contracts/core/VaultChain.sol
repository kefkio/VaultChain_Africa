// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;


import {ILoanManager} from "./interfaces/ILoanManager.sol";
import {IMarketplace} from "./interfaces/IMarketplace.sol";
import {IOracleAggregator} from "./interfaces/IOracleAggregator.sol";
import {IPoolVaultERC4626} from "./interfaces/IPoolVaultERC4626.sol";
import {ITreasury} from "./interfaces/ITreasury.sol";
import {ITimelockController} from "./interfaces/ITimelockController.sol";

contract VaultChain {
    // Core modules as interfaces
    ILoanManager public loanManager;
    IMarketplace public marketplace;
    IOracleAggregator public oracle;
    IPoolVaultERC4626 public poolVault;
    ITreasury public treasury;
    ITimelockController public timelock;

    /// @notice Initializes VaultChain with deployed module addresses
    constructor(
        address _loanManager,
        address _marketplace,
        address _oracle,
        address _poolVault,
        address _treasury,
        address _timelock
    ) {
        // Assign the deployed addresses to the interface variables
        loanManager = ILoanManager(_loanManager);
        marketplace = IMarketplace(_marketplace);
        oracle = IOracleAggregator(_oracle);
        poolVault = IPoolVaultERC4626(_poolVault);
        treasury = ITreasury(_treasury);
        timelock = ITimelockController(_timelock);
    }

    /// @notice Returns VaultChain version
    function version() external pure returns (string memory) {
        return "VaultChain Africa v1.0";
    }
}
