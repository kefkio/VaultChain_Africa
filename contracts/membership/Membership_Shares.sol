// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library MembershipShares {
    function calculateSharesOnJoin(uint8 memberType) internal pure returns (uint256) {
        if (memberType == 2) return 1000; // FOUNDER
        if (memberType == 1) return 500;  // PREMIUM
        return 100;                        // REGULAR
    }
}
