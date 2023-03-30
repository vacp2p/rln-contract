// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {IPoseidonHasher} from "./PoseidonHasher.sol";

/// Invalid deposit amount
/// @param required The required deposit amount
/// @param provided The provided deposit amount
error InsufficientDeposit(uint256 required, uint256 provided);

/// Provided Batch is empty
error EmptyBatch();

/// Batch is full, during batch operations
error FullBatch();

/// Member is already registered
error DuplicateIdCommitment();

/// Batch size mismatch, when the length of secrets and receivers are not equal
/// @param givenSecretsLen The length of the secrets array
/// @param givenReceiversLen The length of the receivers array
error MismatchedBatchSize(uint256 givenSecretsLen, uint256 givenReceiversLen);

/// Invalid withdrawal address, when the receiver is the contract itself or 0x0
error InvalidWithdrawalAddress(address to);

/// Member is not registered
error MemberNotRegistered(uint256 idCommitment);

/// Member has no stake
error MemberHasNoStake(uint256 idCommitment);

contract RLN {
    /// @notice The deposit amount required to register as a member
    uint256 public immutable MEMBERSHIP_DEPOSIT;

    /// @notice The depth of the merkle tree
    uint256 public immutable DEPTH;

    /// @notice The size of the merkle tree, i.e 2^depth
    uint256 public immutable SET_SIZE;

    /// @notice The index of the next member to be registered
    uint256 public idCommitmentIndex;

    /// @notice The amount of eth staked by each member
    mapping(uint256 => uint256) public stakedAmounts;

    /// @notice The membership status of each member
    mapping(uint256 => bool) public members;

    /// @notice The Poseidon hasher contract
    IPoseidonHasher public poseidonHasher;

    /// Emitted when a new member is added to the set
    /// @param idCommitment The idCommitment of the member
    /// @param index The index of the member in the set
    event MemberRegistered(uint256 idCommitment, uint256 index);

    /// Emitted when a member is removed from the set
    /// @param idCommitment The idCommitment of the member
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

    /// Allows a user to register as a member
    /// @param idCommitment The idCommitment of the member
    function register(uint256 idCommitment) external payable {
        if (msg.value != MEMBERSHIP_DEPOSIT)
            revert InsufficientDeposit(MEMBERSHIP_DEPOSIT, msg.value);
        _register(idCommitment, msg.value);
    }

    /// Allows batch registration of members
    /// @param idCommitments array of idCommitments
    function registerBatch(uint256[] calldata idCommitments) external payable {
        uint256 idCommitmentlen = idCommitments.length;
        if (idCommitmentlen == 0) revert EmptyBatch();
        if (idCommitmentIndex + idCommitmentlen >= SET_SIZE) revert FullBatch();
        uint256 requiredDeposit = MEMBERSHIP_DEPOSIT * idCommitmentlen;
        if (msg.value != requiredDeposit)
            revert InsufficientDeposit(requiredDeposit, msg.value);
        for (uint256 i = 0; i < idCommitmentlen; i++) {
            _register(idCommitments[i], msg.value / idCommitmentlen);
        }
    }

    /// Registers a member
    /// @param idCommitment The idCommitment of the member
    /// @param stake The amount of eth staked by the member
    function _register(uint256 idCommitment, uint256 stake) internal {
        if (members[idCommitment]) revert DuplicateIdCommitment();
        if (idCommitmentIndex >= SET_SIZE) revert FullBatch();

        members[idCommitment] = true;
        stakedAmounts[idCommitment] = stake;

        emit MemberRegistered(idCommitment, idCommitmentIndex);
        idCommitmentIndex += 1;
    }

    /// Allows a user to slash a batch of members
    /// @param secrets array of idSecretHashes
    /// @param receivers array of addresses to receive the funds
    function withdrawBatch(
        uint256[] calldata secrets,
        address payable[] calldata receivers
    ) external {
        uint256 batchSize = secrets.length;
        if (batchSize == 0) revert EmptyBatch();
        if (batchSize != receivers.length)
            revert MismatchedBatchSize(secrets.length, receivers.length);
        for (uint256 i = 0; i < batchSize; i++) {
            _withdraw(secrets[i], receivers[i]);
        }
    }

    /// Allows a user to slash a member
    /// @param secret The idSecretHash of the member
    function withdraw(uint256 secret, address payable receiver) external {
        _withdraw(secret, receiver);
    }

    /// Slashes a member by removing them from the set, and transferring their
    /// stake to the receiver
    /// @param secret The idSecretHash of the member
    /// @param receiver The address to receive the funds
    function _withdraw(uint256 secret, address payable receiver) internal {
        if (receiver == address(this) || receiver == address(0))
            revert InvalidWithdrawalAddress(receiver);

        // derive idCommitment
        uint256 idCommitment = hash(secret);
        // check if member is registered
        if (!members[idCommitment]) revert MemberNotRegistered(idCommitment);
        if (stakedAmounts[idCommitment] == 0)
            revert MemberHasNoStake(idCommitment);

        uint256 amountToTransfer = stakedAmounts[idCommitment];

        // delete member
        members[idCommitment] = false;
        stakedAmounts[idCommitment] = 0;

        // refund deposit
        receiver.transfer(amountToTransfer);

        emit MemberWithdrawn(idCommitment);
    }

    /// Hashes a value using the Poseidon hasher
    /// NOTE: The variant of Poseidon we use accepts only 1 input, assume n=2, and the second input is 0
    /// @param input The value to hash
    function hash(uint256 input) internal view returns (uint256) {
        return poseidonHasher.hash(input);
    }
}
