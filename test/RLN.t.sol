// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "../contracts/PoseidonHasher.sol";
import "../contracts/Rln.sol";
import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";

contract RLNTest is Test {
    using stdStorage for StdStorage;

    RLN public rln;
    PoseidonHasher public poseidon;

    uint256 public constant MEMBERSHIP_DEPOSIT = 1000000000000000;
    uint256 public constant DEPTH = 20;
    uint256 public constant SET_SIZE = 1048576;

    /// @dev Setup the testing environment.
    function setUp() public {
        poseidon = new PoseidonHasher();
        uint256[] memory constructMembers = new uint256[](0);
        rln = new RLN(constructMembers, address(poseidon));
    }

    /// @dev Ensure that you can hash a value.
    function test__Constants() public {
        assertEq(rln.DEPTH(), DEPTH);
        assertEq(rln.SET_SIZE(), SET_SIZE);
    }
}
