// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IPoseidonHasher} from "./PoseidonHasher.sol";
import {IValidGroupStorage} from "./ValidGroupStorage.sol";
import {IInterep} from "@interep/contracts/IInterep.sol";

contract RLN {
    uint256 public immutable MEMBERSHIP_DEPOSIT;
    uint256 public immutable DEPTH;
    uint256 public immutable SET_SIZE;

    uint256 public idCommitmentIndex;
    mapping(uint256 => uint256) public stakedAmounts;
    mapping(uint256 => bool) public members;

    IPoseidonHasher public poseidonHasher;
    IValidGroupStorage public validGroupStorage;
    IInterep public interep;

    event MemberRegistered(uint256 idCommitment, uint256 index);
    event MemberWithdrawn(uint256 idCommitment);

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

    function register(uint256 idCommitment) external payable {
        require(
            msg.value == MEMBERSHIP_DEPOSIT,
            "RLN, register: membership deposit is not satisfied"
        );
        _register(idCommitment, msg.value);
    }

    /// @dev Registers a member via a valid Interep Semaphore group.
    /// @param groupId: Id of the group.
    /// @param signal: Semaphore signal.
    /// @param nullifierHash: Nullifier hash.
    /// @param externalNullifier: External nullifier.
    /// @param proof: Zero-knowledge proof.
    /// @param idCommitment: ID Commitment of the member.
    function register(
        uint256 groupId,
        bytes32 signal,
        uint256 nullifierHash,
        uint256 externalNullifier,
        uint256[8] calldata proof,
        uint256 idCommitment
    ) external {
        require(
            validGroupStorage.isValidGroup(groupId),
            "RLN, register: invalid interep group"
        );
        interep.verifyProof(
            groupId,
            signal,
            nullifierHash,
            externalNullifier,
            proof
        );
        _register(idCommitment, 0);
    }

    function registerBatch(uint256[] calldata idCommitments) external payable {
        uint256 idCommitmentlen = idCommitments.length;
        require(
            idCommitmentIndex + idCommitmentlen <= SET_SIZE,
            "RLN, registerBatch: set is full"
        );
        require(
            msg.value == MEMBERSHIP_DEPOSIT * idCommitmentlen,
            "RLN, registerBatch: membership deposit is not satisfied"
        );
        for (uint256 i = 0; i < idCommitmentlen; i++) {
            _register(idCommitments[i], msg.value / idCommitmentlen);
        }
    }

    function _register(uint256 idCommitment, uint256 stake) internal {
        require(
            !members[idCommitment],
            "RLN, _register: member already registered"
        );
        require(idCommitmentIndex < SET_SIZE, "RLN, register: set is full");
        if (stake != 0) {
            members[idCommitment] = true;
            stakedAmounts[idCommitment] = stake;
        } else {
            members[idCommitment] = true;
            stakedAmounts[idCommitment] = 0;
        }
        emit MemberRegistered(idCommitment, idCommitmentIndex);
        idCommitmentIndex += 1;
    }

    function withdrawBatch(
        uint256[] calldata secrets,
        address payable[] calldata receivers
    ) external {
        uint256 batchSize = secrets.length;
        require(batchSize != 0, "RLN, withdrawBatch: batch size zero");
        require(
            batchSize == secrets.length,
            "RLN, withdrawBatch: batch size mismatch secrets"
        );
        require(
            batchSize == receivers.length,
            "RLN, withdrawBatch: batch size mismatch receivers"
        );
        for (uint256 i = 0; i < batchSize; i++) {
            _withdraw(secrets[i], receivers[i]);
        }
    }

    function withdraw(uint256 secret, address payable receiver) external {
        _withdraw(secret, receiver);
    }

    function withdraw(uint256 secret) external {
        _withdraw(secret);
    }

    function _withdraw(uint256 secret, address payable receiver) internal {
        // derive idCommitment
        uint256 idCommitment = hash(secret);

        // check if member is registered
        require(members[idCommitment], "RLN, _withdraw: member not registered");

        // check if member has stake
        require(
            stakedAmounts[idCommitment] != 0,
            "RLN, _withdraw: member has no stake"
        );

        require(
            receiver != address(0),
            "RLN, _withdraw: empty receiver address"
        );

        // refund deposit
        (bool sent, ) = receiver.call{value: stakedAmounts[idCommitment]}("");
        require(sent, "transfer failed");

        // delete member
        members[idCommitment] = false;
        stakedAmounts[idCommitment] = 0;

        emit MemberWithdrawn(idCommitment);
    }

    function _withdraw(uint256 secret) internal {
        // derive idCommitment
        uint256 idCommitment = hash(secret);

        // check if member is registered
        require(members[idCommitment], "RLN, _withdraw: member not registered");

        require(stakedAmounts[idCommitment] == 0, "RLN, _withdraw: staked");

        // delete member
        members[idCommitment] = false;

        emit MemberWithdrawn(idCommitment);
    }

    function hash(uint256 input) internal view returns (uint256) {
        return poseidonHasher.hash(input);
    }
}
