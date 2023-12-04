// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import { IVerifier } from "../../src/IVerifier.sol";

contract TrueVerifier is IVerifier {
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[2] memory input
    )
        external
        pure
        returns (bool)
    {
        return true;
    }
}

contract FalseVerifier is IVerifier {
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[2] memory input
    )
        external
        pure
        returns (bool)
    {
        return false;
    }
}
