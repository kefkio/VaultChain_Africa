// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ITreasury {
    /// @notice Returns the version of the Treasury module
    function version() external pure returns (string memory);

    /// @notice Deposit funds into the treasury
    /// @param amount The amount to deposit
    function depositFunds(uint256 amount) external;

    /// @notice Transfer funds from the treasury to a recipient
    /// @param to The recipient address
    /// @param amount The amount to transfer
    function transferFunds(address to, uint256 amount) external;

    /// @notice Returns the current balance of the treasury
    function balance() external view returns (uint256);
}
