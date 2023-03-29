// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "../contracts/PoseidonHasher.sol";
import "../contracts/Rln.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

contract RLNTest is Test {
    RLN public rln;

    uint256 public constant MEMBERSHIP_DEPOSIT = 1000000000000000;
    uint256 public constant DEPTH = 20;
    uint256 public constant SET_SIZE = 1048576;

    /// @dev Setup the testing environment.
    function setUp() public {
        PoseidonHasher poseidon = new PoseidonHasher();
        rln = new RLN(MEMBERSHIP_DEPOSIT, DEPTH, address(poseidon));
    }

    /// @dev Ensure that you can hash a value.
    function test__Constants() public {
        assertEq(rln.MEMBERSHIP_DEPOSIT(), MEMBERSHIP_DEPOSIT);
        assertEq(rln.DEPTH(), DEPTH);
        assertEq(rln.SET_SIZE(), SET_SIZE);
    }

    function test__ValidRegistration(uint256 idCommitment) public {
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        assertEq(rln.members(idCommitment), true);
    }

    function test__InvalidRegistration__DuplicateCommitment(
        uint256 idCommitment
    ) public {
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        assertEq(rln.members(idCommitment), true);
        vm.expectRevert(bytes("RLN, _register: member already registered"));
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
    }

    function test__InvalidRegistration__InsufficientDeposit(
        uint256 idCommitment
    ) public {
        vm.expectRevert(
            bytes("RLN, register: membership deposit is not satisfied")
        );
        rln.register{value: MEMBERSHIP_DEPOSIT - 1}(idCommitment);
    }

    function test__InvalidRegistration__FullSet(
        uint256 idCommitmentSeed
    ) public {
        vm.assume(idCommitmentSeed < 2 ** 255 - SET_SIZE);
        RLN tempRln = new RLN(
            MEMBERSHIP_DEPOSIT,
            2,
            address(rln.poseidonHasher())
        );
        uint256 setSize = tempRln.SET_SIZE();
        for (uint256 i = 0; i < setSize; i++) {
            tempRln.register{value: MEMBERSHIP_DEPOSIT}(idCommitmentSeed + i);
        }
        assertEq(tempRln.idCommitmentIndex(), 4);
        vm.expectRevert(bytes("RLN, register: set is full"));
        tempRln.register{value: MEMBERSHIP_DEPOSIT}(idCommitmentSeed + setSize);
    }
}
