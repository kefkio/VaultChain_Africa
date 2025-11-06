// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

library MembershipShares {
    uint256 public constant DEFAULT_SHARES = 1;

    function calculateSharesOnJoin() internal pure returns (uint256) {
        return DEFAULT_SHARES;
    }

    function addShares(uint256 current, uint256 additional) internal pure returns (uint256) {
        return current + additional;
    }

    function subtractShares(uint256 current, uint256 deduction) internal pure returns (uint256) {
        require(current >= deduction, "Insufficient shares");
        return current - deduction;
    }
}