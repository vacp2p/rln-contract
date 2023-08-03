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
