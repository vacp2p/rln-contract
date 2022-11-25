// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@interep/contracts/IInterep.sol";
import "@semaphore-protocol/contracts/interfaces/IVerifier.sol";
import "@semaphore-protocol/contracts/base/SemaphoreCore.sol";
import "@semaphore-protocol/contracts/base/SemaphoreConstants.sol";

contract InterepTest is IInterep, SemaphoreCore {
    mapping(uint256 => Group) public groups;

    /// @dev mimics https://github.com/interep-project/contracts/blob/main/contracts/Interep.sol but ignores the verification mechanism
    constructor() {}

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

    function verifyProof(
        uint256 groupId,
        bytes32 signal,
        uint256 nullifierHash,
        uint256 externalNullifier,
        uint256[8] calldata proof
    ) external override {}
}
