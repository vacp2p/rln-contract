// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@interep/contracts/IInterep.sol";
import "@semaphore-protocol/contracts/interfaces/IVerifier.sol";
import "@semaphore-protocol/contracts/base/SemaphoreCore.sol";
import "@semaphore-protocol/contracts/base/SemaphoreConstants.sol";

contract InterepTest is IInterep, SemaphoreCore {
    /// @dev Gets a tree depth and returns its verifier address.
    mapping(uint8 => IVerifier) public verifiers;

    mapping(uint256 => Group) public groups;

    /// @dev Checks if there is a verifier for the given tree depth.
    /// @param depth: Depth of the tree.
    modifier onlySupportedDepth(uint8 depth) {
        require(
            address(verifiers[depth]) != address(0),
            "Interep: tree depth is not supported"
        );
        _;
    }

    /// @dev Initializes the Semaphore verifiers used to verify the user's ZK proofs.
    /// @param _verifiers: List of Semaphore verifiers (address and related Merkle tree depth).
    constructor(Verifier[] memory _verifiers) {
        for (uint8 i = 0; i < _verifiers.length; i++) {
            verifiers[_verifiers[i].merkleTreeDepth] = IVerifier(
                _verifiers[i].contractAddress
            );
        }
    }

    /// @dev See {IInterep-updateGroups}.
    function updateGroups(Group[] calldata _groups) external override {
        for (uint8 i = 0; i < _groups.length; i++) {
            uint256 groupId = uint256(
                keccak256(
                    abi.encodePacked(_groups[i].provider, _groups[i].name)
                )
            ) % SNARK_SCALAR_FIELD;

            _updateGroup(groupId, _groups[i]);
        }
    }

    /// @dev See {IInterep-getRoot}.
    function getRoot(uint256 groupId) public view override returns (uint256) {
        return groups[groupId].root;
    }

    /// @dev See {IInterep-getDepth}.
    function getDepth(uint256 groupId) public view override returns (uint8) {
        return groups[groupId].depth;
    }

    /// @dev Updates an Interep group.
    /// @param groupId: Id of the group.
    /// @param group: Group data.
    function _updateGroup(uint256 groupId, Group calldata group) private {
        groups[groupId] = group;

        emit GroupUpdated(
            groupId,
            group.provider,
            group.name,
            group.root,
            group.depth
        );
    }

    /// @dev See {IInterep-verifyProof}.
    function verifyProof(
        uint256 groupId,
        bytes32 signal,
        uint256 nullifierHash,
        uint256 externalNullifier,
        uint256[8] calldata proof
    ) external override {
        uint256 root = getRoot(groupId);
        uint8 depth = getDepth(groupId);

        require(depth != 0, "Interep: group does not exist");

        IVerifier verifier = verifiers[depth];

        _verifyProof(
            signal,
            root,
            nullifierHash,
            externalNullifier,
            proof,
            verifier
        );

        // TODO: check if the nullifier is not used before
        // _saveNullifierHash(nullifierHash);

        emit ProofVerified(groupId, signal);
    }
}
