// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IPoseidonHasher} from "rln-contract/PoseidonHasher.sol";
import {RlnBase, DuplicateIdCommitment, FullTree, InvalidIdCommitment} from "rln-contract/RlnBase.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

error NotImplemented();

contract WakuRln is Ownable, RlnBase {
    uint16 public immutable contractIndex;

    constructor(
        address _poseidonHasher,
        uint16 _contractIndex
    ) Ownable() RlnBase(0, 20, _poseidonHasher, address(0)) {
        contractIndex = _contractIndex;
    }

    /// Registers a member
    /// @param idCommitment The idCommitment of the member
    function _register(uint256 idCommitment) internal {
        _validateRegistration(idCommitment);

        members[idCommitment] = idCommitmentIndex;
        memberExists[idCommitment] = true;

        emit MemberRegistered(idCommitment, idCommitmentIndex);
        idCommitmentIndex += 1;
    }

    function register(uint256[] calldata idCommitments) external onlyOwner {
        uint256 len = idCommitments.length;
        for (uint256 i = 0; i < len; ) {
            _register(idCommitments[i]);
            unchecked {
                ++i;
            }
        }
    }

    function register(uint256 idCommitment) external payable override {
        revert NotImplemented();
    }

    function slash(
        uint256 idCommitment,
        address payable receiver,
        uint256[8] calldata proof
    ) external pure override {
        revert NotImplemented();
    }

    function _validateRegistration(
        uint256 idCommitment
    ) internal view override {
        if (!isValidCommitment(idCommitment))
            revert InvalidIdCommitment(idCommitment);
        if (memberExists[idCommitment] == true) revert DuplicateIdCommitment();
        if (idCommitmentIndex >= SET_SIZE) revert FullTree();
    }

    function _validateSlash(
        uint256 idCommitment,
        address payable receiver,
        uint256[8] calldata proof
    ) internal pure override {
        revert NotImplemented();
    }

    function withdraw() external pure override {
        revert NotImplemented();
    }
}
