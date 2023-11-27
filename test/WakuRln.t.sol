// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {PoseidonHasher} from "rln-contract/PoseidonHasher.sol";
import "./utils.sol";
import "../contracts/WakuRln.sol";
import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";

contract WakuRlnTest is Test {
    using stdStorage for StdStorage;

    WakuRln public wakuRln;
    PoseidonHasher public poseidon;

    uint256 public constant MEMBERSHIP_DEPOSIT = 1000000000000000;
    uint256 public constant DEPTH = 20;
    uint256 public constant SET_SIZE = 1048576;

    uint256[8] public zeroedProof = [0, 0, 0, 0, 0, 0, 0, 0];

    /// @dev Setup the testing environment.
    function setUp() public {
        poseidon = new PoseidonHasher();
        wakuRln = new WakuRln(address(poseidon), 0);
    }

    /// @dev Ensure that you can hash a value.
    function test__Constants() public {
        assertEq(wakuRln.DEPTH(), DEPTH);
        assertEq(wakuRln.SET_SIZE(), SET_SIZE);
        assertEq(wakuRln.deployedBlockNumber(), block.number);
    }

    function test__ValidRegistration(uint256[] calldata idCommitments) public {
        // Register a batch of commitments
        vm.assume(idCommitments.length < 10_000);
        vm.assume(noDuplicate(idCommitments));
        vm.assume(noInvalidCommitment(idCommitments, poseidon.Q()));
        wakuRln.register(idCommitments);
    }

    function test__ValidRegistration_InTree(uint256[] calldata idCommitments) public {
        // Register a batch of commitments
        vm.assume(idCommitments.length < 10_000);
        vm.assume(noDuplicate(idCommitments));
        vm.assume(noInvalidCommitment(idCommitments, poseidon.Q()));
        wakuRln.register(idCommitments);

        //wakuRln.numOfLeaves()
        //vm.assume(1 == 2);

        //assertEq(wakuRln.register(idCommitments), 1);
    }

    function test__InvalidRegistration__Duplicate() public {
        // Register a batch of commitments
        uint256[] memory idCommitments = new uint256[](2);
        idCommitments[0] = 1;
        idCommitments[1] = 1;
        vm.expectRevert(DuplicateIdCommitment.selector);
        wakuRln.register(idCommitments);
    }

    function test__InvalidFeatures() public {
        uint256 idCommitment = 1;
        vm.expectRevert(NotImplemented.selector);
        wakuRln.register(idCommitment);
        vm.expectRevert(NotImplemented.selector);
        wakuRln.slash(idCommitment, payable(address(0)), zeroedProof);
        vm.expectRevert(NotImplemented.selector);
        wakuRln.withdraw();
    }
}
