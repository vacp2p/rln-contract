// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { IVerifier } from "./IVerifier.sol";
import { PoseidonT3 } from "poseidon-solidity/PoseidonT3.sol";

/// The tree is full
error FullTree();

/// Invalid deposit amount
/// @param required The required deposit amount
/// @param provided The provided deposit amount
error InsufficientDeposit(uint256 required, uint256 provided);

/// Member is already registered
error DuplicateRateCommitment();

/// Failed validation on registration/slashing
error FailedValidation();

/// Invalid idCommitment
error InvalidIdCommitment(uint256 idCommitment);

/// Invalid userMessageLimit
error InvalidUserMessageLimit(uint256 messageLimit);

/// Invalid receiver address, when the receiver is the contract itself or 0x0
error InvalidReceiverAddress(address to);

/// Member is not registered
error MemberNotRegistered(uint256 idCommitment);

/// Member has no stake
error MemberHasNoStake(uint256 idCommitment);

/// User has insufficient balance to withdraw
error InsufficientWithdrawalBalance();

/// Contract has insufficient balance to return
error InsufficientContractBalance();

/// Invalid proof
error InvalidProof();

/// Invalid pagination query
error InvalidPaginationQuery(uint256 startIndex, uint256 endIndex);

abstract contract RlnBase {
    /// @notice The Field
    uint256 public constant Q =
        21_888_242_871_839_275_222_246_405_745_257_275_088_548_364_400_416_034_343_698_204_186_575_808_495_617;

    /// @notice The max message limit per epoch
    uint256 public constant MAX_MESSAGE_LIMIT = 20;

    /// @notice The deposit amount required to register as a member
    uint256 public immutable MEMBERSHIP_DEPOSIT;

    /// @notice The depth of the merkle tree
    uint256 public immutable DEPTH;

    /// @notice The size of the merkle tree, i.e 2^depth
    uint256 public immutable SET_SIZE;

    /// @notice The index of the next member to be registered
    uint256 public rateCommitmentIndex = 0;

    /// @notice The amount of eth staked by each member
    /// maps from idCommitment to the amount staked
    mapping(uint256 => uint256) public stakedAmounts;

    /// @notice The membership status of each member
    /// maps from idCommitment to their index in the set
    mapping(uint256 => uint256) public members;

    /// @notice the user message limit of each member
    /// maps from idCommitment to their user message limit
    mapping(uint256 => uint256) public userMessageLimits;

    /// @notice the index to commitment mapping
    mapping(uint256 => uint256) public indexToCommitment;

    /// @notice The membership status of each member
    mapping(uint256 => bool) public memberExists;

    /// @notice The balance of each user that can be withdrawn
    mapping(address => uint256) public withdrawalBalance;

    /// @notice The groth16 verifier contract
    IVerifier public immutable verifier;

    /// @notice the deployed block number
    uint32 public immutable deployedBlockNumber;

    /// Emitted when a new member is added to the set
    /// @param idCommitment The idCommitment of the member
    /// @param index The index of the member in the set
    event MemberRegistered(uint256 idCommitment, uint256 index);

    /// Emitted when a member is removed from the set
    /// @param idCommitment The idCommitment of the member
    /// @param index The index of the member in the set
    event MemberWithdrawn(uint256 idCommitment, uint256 index);

    modifier onlyValidIdCommitment(uint256 idCommitment) {
        if (!isValidCommitment(idCommitment)) revert InvalidIdCommitment(idCommitment);
        _;
    }

    modifier onlyValidUserMessageLimit(uint256 messageLimit) {
        if (messageLimit > MAX_MESSAGE_LIMIT) revert InvalidUserMessageLimit(messageLimit);
        if (messageLimit == 0) revert InvalidUserMessageLimit(messageLimit);
        _;
    }

    constructor(uint256 membershipDeposit, uint256 depth, address _verifier) {
        MEMBERSHIP_DEPOSIT = membershipDeposit;
        DEPTH = depth;
        SET_SIZE = 1 << depth;
        verifier = IVerifier(_verifier);
        deployedBlockNumber = uint32(block.number);
    }

    /// Returns the deposit amount required to register as a member
    /// @param userMessageLimit The message limit of the member
    /// TODO: update this function as per tokenomics design
    function getDepositAmount(uint256 userMessageLimit) public view returns (uint256) {
        return userMessageLimit * MEMBERSHIP_DEPOSIT;
    }

    /// Allows a user to register as a member
    /// @param idCommitment The idCommitment of the member
    /// @param userMessageLimit The message limit of the member
    function register(
        uint256 idCommitment,
        uint256 userMessageLimit
    )
        external
        payable
        virtual
        onlyValidIdCommitment(idCommitment)
        onlyValidUserMessageLimit(userMessageLimit)
    {
        uint256 requiredDeposit = userMessageLimit * MEMBERSHIP_DEPOSIT;
        if (msg.value != requiredDeposit) {
            revert InsufficientDeposit(MEMBERSHIP_DEPOSIT, msg.value);
        }
        _validateRegistration(idCommitment);
        _register(idCommitment, msg.value);
    }

    /// Registers a member
    /// @param idCommitment The idCommitment of the member
    /// @param userMessageLimit The message limit of the member
    /// @param stake The amount of eth staked by the member
    function _register(uint256 idCommitment, uint256 userMessageLimit, uint256 stake) internal virtual {
        uint256 rateCommitment = PoseidonT3.hash([idCommitment, userMessageLimit]);
        if (memberExists[rateCommitment]) revert DuplicateRateCommitment();
        if (rateCommitmentIndex >= SET_SIZE) revert FullTree();

        members[rateCommitment] = rateCommitmentIndex;
        indexToCommitment[rateCommitmentIndex] = rateCommitment;
        memberExists[rateCommitment] = true;
        stakedAmounts[rateCommitment] = stake;
        userMessageLimits[idCommitment] = userMessageLimit;

        emit MemberRegistered(rateCommitment, rateCommitmentIndex);
        rateCommitmentIndex += 1;
    }

    /// @dev Inheriting contracts MUST override this function
    function _validateRegistration(uint256 idCommitment) internal view virtual;

    /// @dev Allows a user to slash a member
    /// @param idCommitment The idCommitment of the member
    function slash(
        uint256 idCommitment,
        address payable receiver,
        uint256[8] calldata proof
    )
        external
        virtual
        onlyValidIdCommitment(idCommitment)
    {
        _validateSlash(idCommitment, receiver, proof);
        _slash(idCommitment, receiver, proof);
    }

    /// @dev Slashes a member by removing them from the set, and adding their
    /// stake to the receiver's available withdrawal balance
    /// @param idCommitment The idCommitment of the member
    /// @param receiver The address to receive the funds
    function _slash(uint256 idCommitment, address payable receiver, uint256[8] calldata proof) internal virtual {
        if (receiver == address(this) || receiver == address(0)) {
            revert InvalidReceiverAddress(receiver);
        }

        uint256 userMessageLimit = userMessageLimits[idCommitment];
        uint256 rateCommitment = PoseidonT3.hash([idCommitment, userMessageLimit]);
        if (memberExists[rateCommitment] == false) revert MemberNotRegistered(rateCommitment);
        // check if member is registered
        if (stakedAmounts[rateCommitment] == 0) {
            revert MemberHasNoStake(rateCommitment);
        }

        if (!_verifyProof(rateCommitment, receiver, proof)) {
            revert InvalidProof();
        }

        uint256 amountToTransfer = stakedAmounts[rateCommitment];

        // delete member
        uint256 index = members[rateCommitment];
        members[rateCommitment] = 0;
        indexToCommitment[index] = 0;
        memberExists[rateCommitment] = false;
        stakedAmounts[rateCommitment] = 0;
        userMessageLimits[idCommitment] = 0;

        // refund deposit
        withdrawalBalance[receiver] += amountToTransfer;

        emit MemberWithdrawn(idCommitment, index);
    }

    function _validateSlash(
        uint256 idCommitment,
        address payable receiver,
        uint256[8] calldata proof
    )
        internal
        view
        virtual;

    /// Allows a user to withdraw funds allocated to them upon slashing a member
    function withdraw() external virtual {
        uint256 amount = withdrawalBalance[msg.sender];

        if (amount == 0) revert InsufficientWithdrawalBalance();
        if (amount > address(this).balance) {
            revert InsufficientContractBalance();
        }

        withdrawalBalance[msg.sender] = 0;

        payable(msg.sender).transfer(amount);
    }

    function isValidCommitment(uint256 idCommitment) public pure returns (bool) {
        return idCommitment != 0 && idCommitment < Q;
    }

    /// @dev Groth16 proof verification
    function _verifyProof(
        uint256 idCommitment,
        address receiver,
        uint256[8] calldata proof
    )
        internal
        view
        virtual
        returns (bool)
    {
        return verifier.verifyProof(
            [proof[0], proof[1]],
            [[proof[2], proof[3]], [proof[4], proof[5]]],
            [proof[6], proof[7]],
            [idCommitment, uint256(uint160(receiver))]
        );
    }

    function getCommitments(uint256 startIndex, uint256 endIndex) public view returns (uint256[] memory) {
        if (startIndex >= endIndex) revert InvalidPaginationQuery(startIndex, endIndex);
        if (endIndex > rateCommitmentIndex) revert InvalidPaginationQuery(startIndex, endIndex);

        uint256[] memory commitments = new uint256[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            commitments[i - startIndex] = indexToCommitment[i];
        }
        return commitments;
    }
}
