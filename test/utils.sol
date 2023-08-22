// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

function noDuplicate(uint256[] calldata ids) pure returns (bool) {
    uint256 len = ids.length;
    for (uint256 i = 0; i < len; i++) {
        for (uint256 j = i + 1; j < len; j++) {
            if (ids[i] == ids[j]) {
                return false;
            }
        }
    }
    return true;
}

function noInvalidCommitment(uint256[] calldata ids, uint256 p) pure returns (bool) {
    uint256 len = ids.length;
    for (uint256 i = 0; i < len; i++) {
        if (!isValidCommitment(ids[i], p)) {
            return false;
        }
    }
    return true;
}

function isValidCommitment(uint256 id, uint256 p) pure returns (bool) {
    return id < p && id != 0;
}
