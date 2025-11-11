// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IMarketplace {
    function version() external pure returns (string memory);

    // Add public/external Marketplace functions
    // e.g.,
    // function listCollateral(uint256 tokenId) external;
    // function buyCollateral(uint256 tokenId) external payable;
}
