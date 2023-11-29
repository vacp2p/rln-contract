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
        assertEq(poseidon.hash([value, 0]), poseidon.hash([value, 0]));
    }

    function testHasher() public {
        assertEq(
            poseidon.hash([19014214495641488759237505126948346942972912379615652741039992445865937985820, 0]),
            13164376930590487041313497514223288845711140604177161029957349518915056324115
        );
    }
}
