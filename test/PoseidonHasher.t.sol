// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "../contracts/PoseidonHasher.sol";
import "forge-std/Test.sol";

contract PoseidonHasherTest is Test {
    PoseidonHasher public poseidon;

    /// @dev Setup the testing environment.
    function setUp() public {
        poseidon = new PoseidonHasher();
    }

    /// @dev Ensure that you can hash a value.
    function testHasher(uint256 value) public {
        assertEq(poseidon.hash(value), poseidon.hash(value));
    }

    function testHasher() public {
        assertEq(
            poseidon.hash(19014214495641488759237505126948346942972912379615652741039992445865937985820),
            0x0c3ac305f6a4fe9bfeb3eba978bc876e2a99208b8b56c80160cfb54ba8f02368
        );
    }
}
