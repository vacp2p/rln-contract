// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {IPoseidonHasher} from "./PoseidonHasher.sol";

/// The tree is full
error FullTree();

/// Member is already registered
error DuplicateIdCommitment();

contract RLN {
    /// @notice The depth of the merkle tree
    uint256 public immutable DEPTH = 20;

    /// @notice The size of the merkle tree, i.e 2^depth
    uint256 public immutable SET_SIZE;

    /// @notice The index of the next member to be registered
    uint256 public idCommitmentIndex = 1;

    /// @notice The membership status of each member
    /// maps from idCommitment to their index in the set
    mapping(uint256 => bool) public members;

    /// @notice The Poseidon hasher contract
    IPoseidonHasher public immutable poseidonHasher;

    /// Emitted when a new member is added to the set
    /// @param idCommitment The idCommitment of the member
    /// @param index The index of the member in the set
    event MemberRegistered(uint256 idCommitment, uint256 index);

    constructor(uint256[] memory constructMembers, address _poseidonHasher) {
        poseidonHasher = IPoseidonHasher(_poseidonHasher);
        SET_SIZE = 1 << DEPTH;
        if (constructMembers.length > SET_SIZE) revert FullTree();
        for (uint256 i = 0; i < constructMembers.length; i++) {
            _register(constructMembers[i]);
        }
    }

    /// Registers a member
    /// @param idCommitment The idCommitment of the member
    function _register(uint256 idCommitment) internal {
        if (members[idCommitment] != false) revert DuplicateIdCommitment();

        members[idCommitment] = true;

        emit MemberRegistered(idCommitment, idCommitmentIndex);
        idCommitmentIndex += 1;
    }

    /// Hashes a value using the Poseidon hasher
    /// NOTE: The variant of Poseidon we use accepts only 1 input, assume n=2, and the second input is 0
    /// @param input The value to hash
    function hash(uint256 input) internal view returns (uint256) {
        return poseidonHasher.hash(input);
    }
}
