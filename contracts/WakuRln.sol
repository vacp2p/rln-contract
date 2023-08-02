// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IPoseidonHasher} from "rln-contract/PoseidonHasher.sol";
import {RlnBase, DuplicateIdCommitment} from "rln-contract/RlnBase.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

error NotImplemented();

contract WakuRln is Ownable, RlnBase {
    constructor(address _poseidonHasher) Ownable() RlnBase(0, 20, _poseidonHasher, address(0)) {}

    /// Registers a member
    /// @param idCommitment The idCommitment of the member
    function _register(uint256 idCommitment) internal {
        _validateRegistration(idCommitment);

        members[idCommitment] = 1;

        emit MemberRegistered(idCommitment, idCommitmentIndex);
        idCommitmentIndex += 1;
    }

    function register(uint256[] memory idCommitments) external onlyOwner {
        uint256 len = idCommitments.length;
        for (uint256 i = 0; i < len;) {
            _register(idCommitments[i]);
            unchecked {
                ++i;
            }
        }
    }

    function register(uint256 idCommitment) external payable override {
        revert NotImplemented();
    }

    function slash(uint256 idCommitment, address payable receiver, uint256[8] calldata proof) external pure override {
        revert NotImplemented();
    }

    function _validateRegistration(uint256 idCommitment) internal view override {
        if (members[idCommitment] != 0) revert DuplicateIdCommitment();
    }

    function _validateSlash(uint256 idCommitment, address payable receiver, uint256[8] calldata proof)
        internal
        pure
        override
    {
        revert NotImplemented();
    }

    function withdraw() external pure override {
        revert NotImplemented();
    }
}
