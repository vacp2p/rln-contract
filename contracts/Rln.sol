// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IPoseidonHasher} from "./PoseidonHasher.sol";
import {IValidGroupStorage} from "./ValidGroupStorage.sol";
import {IInterep} from "@interep/contracts/IInterep.sol";

contract RLN {
    uint256 public immutable MEMBERSHIP_DEPOSIT;
    uint256 public immutable DEPTH;
    uint256 public immutable SET_SIZE;

    uint256 public pubkeyIndex = 0;
    mapping(uint256 => uint256) public members;

    IPoseidonHasher public poseidonHasher;
    IValidGroupStorage public validGroupStorage;
    IInterep public interep;

    event MemberRegistered(uint256 pubkey, uint256 index);
    event MemberWithdrawn(uint256 pubkey, uint256 index);

    constructor(
        uint256 membershipDeposit,
        uint256 depth,
        address _poseidonHasher,
        address _validGroupStorage
    ) {
        MEMBERSHIP_DEPOSIT = membershipDeposit;
        DEPTH = depth;
        SET_SIZE = 1 << depth;
        poseidonHasher = IPoseidonHasher(_poseidonHasher);
        validGroupStorage = IValidGroupStorage(_validGroupStorage);
        interep = IInterep(validGroupStorage.interep());
    }

    function register(uint256 pubkey) external payable {
        require(pubkeyIndex < SET_SIZE, "RLN, register: set is full");
        require(
            msg.value == MEMBERSHIP_DEPOSIT,
            "RLN, register: membership deposit is not satisfied"
        );
        _register(pubkey);
    }

    /// @dev Registers a member via a valid Interep Semaphore group.
    /// @param groupId: Id of the group.
    /// @param signal: Semaphore signal.
    /// @param nullifierHash: Nullifier hash.
    /// @param externalNullifier: External nullifier.
    /// @param proof: Zero-knowledge proof.
    /// @param pubkey: Public key of the member.
    function register(
        uint256 groupId,
        bytes32 signal,
        uint256 nullifierHash,
        uint256 externalNullifier,
        uint256[8] calldata proof,
        uint256 pubkey
    ) external {
        require(
            validGroupStorage.isValidGroup(groupId),
            "RLN, register: invalid interep group"
        );
        require(pubkeyIndex < SET_SIZE, "RLN, register: set is full");
        interep.verifyProof(
            groupId,
            signal,
            nullifierHash,
            externalNullifier,
            proof
        );
        _register(pubkey);
    }

    function registerBatch(uint256[] calldata pubkeys) external payable {
        uint256 pubkeylen = pubkeys.length;
        require(
            pubkeyIndex + pubkeylen <= SET_SIZE,
            "RLN, registerBatch: set is full"
        );
        require(
            msg.value == MEMBERSHIP_DEPOSIT * pubkeylen,
            "RLN, registerBatch: membership deposit is not satisfied"
        );
        for (uint256 i = 0; i < pubkeylen; i++) {
            _register(pubkeys[i]);
        }
    }

    function _register(uint256 pubkey) internal {
        members[pubkeyIndex] = pubkey;
        emit MemberRegistered(pubkey, pubkeyIndex);
        pubkeyIndex += 1;
    }

    function withdrawBatch(
        uint256[] calldata secrets,
        uint256[] calldata pubkeyIndexes,
        address payable[] calldata receivers
    ) external {
        uint256 batchSize = secrets.length;
        require(batchSize != 0, "RLN, withdrawBatch: batch size zero");
        require(
            batchSize == pubkeyIndexes.length,
            "RLN, withdrawBatch: batch size mismatch pubkey indexes"
        );
        require(
            batchSize == receivers.length,
            "RLN, withdrawBatch: batch size mismatch receivers"
        );
        for (uint256 i = 0; i < batchSize; i++) {
            _withdraw(secrets[i], pubkeyIndexes[i], receivers[i]);
        }
    }

    function withdraw(
        uint256 secret,
        uint256 _pubkeyIndex,
        address payable receiver
    ) external {
        _withdraw(secret, _pubkeyIndex, receiver);
    }

    function _withdraw(
        uint256 secret,
        uint256 _pubkeyIndex,
        address payable receiver
    ) internal {
        require(
            _pubkeyIndex < SET_SIZE,
            "RLN, _withdraw: invalid pubkey index"
        );
        require(
            members[_pubkeyIndex] != 0,
            "RLN, _withdraw: member doesn't exist"
        );
        require(
            receiver != address(0),
            "RLN, _withdraw: empty receiver address"
        );

        // derive public key
        uint256 pubkey = hash(secret);
        require(
            members[_pubkeyIndex] == pubkey,
            "RLN, _withdraw: not verified"
        );

        // delete member
        members[_pubkeyIndex] = 0;

        // refund deposit
        (bool sent, bytes memory data) = receiver.call{
            value: MEMBERSHIP_DEPOSIT
        }("");
        require(sent, "transfer failed");

        emit MemberWithdrawn(pubkey, _pubkeyIndex);
    }

    function hash(uint256 input) internal view returns (uint256) {
        return poseidonHasher.hash(input);
    }
}
