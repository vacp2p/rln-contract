// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import {IVerifier} from "../contracts/IVerifier.sol";

contract TrueVerifier is IVerifier {
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[2] memory input
    ) external view returns (bool) {
        return true;
    }
}

contract FalseVerifier is IVerifier {
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[2] memory input
    ) external view returns (bool) {
        return false;
    }
}