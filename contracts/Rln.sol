// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {IPoseidonHasher} from "./PoseidonHasher.sol";

contract RLN {
    uint256 public immutable MEMBERSHIP_DEPOSIT;
    uint256 public immutable DEPTH;
    uint256 public immutable SET_SIZE;

    uint256 public idCommitmentIndex;
    mapping(uint256 => uint256) public stakedAmounts;
    mapping(uint256 => bool) public members;

    IPoseidonHasher public poseidonHasher;

    event MemberRegistered(uint256 idCommitment, uint256 index);
    event MemberWithdrawn(uint256 idCommitment);

    constructor(
        uint256 membershipDeposit,
        uint256 depth,
        address _poseidonHasher
    ) {
        MEMBERSHIP_DEPOSIT = membershipDeposit;
        DEPTH = depth;
        SET_SIZE = 1 << depth;
        poseidonHasher = IPoseidonHasher(_poseidonHasher);
    }

    function register(uint256 idCommitment) external payable {
        require(
            msg.value == MEMBERSHIP_DEPOSIT,
            "RLN, register: membership deposit is not satisfied"
        );
        _register(idCommitment, msg.value);
    }

    function registerBatch(uint256[] calldata idCommitments) external payable {
        uint256 idCommitmentlen = idCommitments.length;
        require(idCommitmentlen > 0, "RLN, registerBatch: batch size zero");
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

        members[idCommitment] = true;
        stakedAmounts[idCommitment] = stake;

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

    function _withdraw(uint256 secret, address payable receiver) internal {
        require(
            receiver != address(0),
            "RLN, _withdraw: empty receiver address"
        );

        require(
            receiver != address(this),
            "RLN, _withdraw: cannot withdraw to RLN"
        );

        // derive idCommitment
        uint256 idCommitment = hash(secret);
        // check if member is registered
        require(members[idCommitment], "RLN, _withdraw: member not registered");

        // check if member has stake
        require(
            stakedAmounts[idCommitment] != 0,
            "RLN, _withdraw: member has no stake"
        );

        uint256 amountToTransfer = stakedAmounts[idCommitment];

        // delete member
        members[idCommitment] = false;
        stakedAmounts[idCommitment] = 0;

        // refund deposit
        receiver.transfer(amountToTransfer);

        emit MemberWithdrawn(idCommitment);
    }

    function hash(uint256 input) internal view returns (uint256) {
        return poseidonHasher.hash(input);
    }
}
