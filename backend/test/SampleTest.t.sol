// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";




contract SampleTest is Test {
    function testAddition() public pure{
        uint256 a = 2;
        uint256 b = 3;
        uint256 result = a + b;
        assertEq(result, 5, "2 + 3 should equal 5");
    }

    function testSubtraction() public pure
    {
        uint256 a = 10;
        uint256 b = 4;
        uint256 result = a - b;
        assertEq(result, 6, "10 - 4 should equal 6");
    }
}
