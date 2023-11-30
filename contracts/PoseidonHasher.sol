// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {PoseidonT3} from "poseidon-solidity/PoseidonT3.sol";

interface IPoseidonHasher {
    /// @notice Hashes the input using the Poseidon hash function, n = 2
    /// @param inputs The input to hash
    function hash(uint256[2] memory inputs) external pure returns (uint256 result);
}

contract PoseidonHasher is IPoseidonHasher {
    uint256 public constant Q = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    function hash(uint256[2] memory inputs) external pure override returns (uint256 result) {
        return PoseidonT3.hash(inputs);
    }
}
