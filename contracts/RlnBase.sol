// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {PoseidonHasher} from "./PoseidonHasher.sol";
import {IVerifier} from "./IVerifier.sol";
import {BinaryIMT, BinaryIMTData} from "@zk-kit/imt.sol/BinaryIMT.sol";

/// The tree is full
error FullTree();

/// Invalid deposit amount
/// @param required The required deposit amount
/// @param provided The provided deposit amount
error InsufficientDeposit(uint256 required, uint256 provided);

/// Member is already registered
error DuplicateIdCommitment();

/// Failed validation on registration/slashing
error FailedValidation();

/// Invalid idCommitment
error InvalidIdCommitment(uint256 idCommitment);

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

abstract contract RlnBase {
    /// @notice The deposit amount required to register as a member
    uint256 public immutable MEMBERSHIP_DEPOSIT;

    /// @notice The depth of the merkle tree
    uint256 public immutable DEPTH;

    /// @notice The size of the merkle tree, i.e 2^depth
    uint256 public immutable SET_SIZE;

    /// @notice The index of the next member to be registered
    uint256 public idCommitmentIndex = 0;

    /// @notice The amount of eth staked by each member
    /// maps from idCommitment to the amount staked
    mapping(uint256 => uint256) public stakedAmounts;

    /// @notice The membership status of each member
    /// maps from idCommitment to their index in the set
    mapping(uint256 => uint256) public members;

    /// @notice The membership status of each member
    mapping(uint256 => bool) public memberExists;

    /// @notice The balance of each user that can be withdrawn
    mapping(address => uint256) public withdrawalBalance;

    /// @notice The Poseidon hasher contract
    PoseidonHasher public immutable poseidonHasher;

    /// @notice The groth16 verifier contract
    IVerifier public immutable verifier;

    /// @notice the deployed block number
    uint32 public immutable deployedBlockNumber;

    /// @notice the Incremental Merkle Tree
    BinaryIMTData public imtData;

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

    constructor(uint256 membershipDeposit, uint256 depth, address _poseidonHasher, address _verifier) {
        MEMBERSHIP_DEPOSIT = membershipDeposit;
        DEPTH = depth;
        SET_SIZE = 1 << depth;
        poseidonHasher = PoseidonHasher(_poseidonHasher);
        verifier = IVerifier(_verifier);
        deployedBlockNumber = uint32(block.number);
        BinaryIMT.initWithDefaultZeroes(imtData, 20);
    }

    /// Allows a user to register as a member
    /// @param idCommitment The idCommitment of the member
    function register(uint256 idCommitment) external payable virtual onlyValidIdCommitment(idCommitment) {
        if (msg.value != MEMBERSHIP_DEPOSIT) {
            revert InsufficientDeposit(MEMBERSHIP_DEPOSIT, msg.value);
        }
        _validateRegistration(idCommitment);
        _register(idCommitment, msg.value);
    }

    /// Registers a member
    /// @param idCommitment The idCommitment of the member
    /// @param stake The amount of eth staked by the member
    function _register(uint256 idCommitment, uint256 stake) internal virtual {
        if (memberExists[idCommitment]) revert DuplicateIdCommitment();
        if (idCommitmentIndex >= SET_SIZE) revert FullTree();

        members[idCommitment] = idCommitmentIndex;
        memberExists[idCommitment] = true;
        BinaryIMT.insert(imtData, idCommitment);
        stakedAmounts[idCommitment] = stake;

        emit MemberRegistered(idCommitment, idCommitmentIndex);
        idCommitmentIndex += 1;
    }

    /// @dev Inheriting contracts MUST override this function
    function _validateRegistration(uint256 idCommitment) internal view virtual;

    /// @dev Allows a user to slash a member
    /// @param idCommitment The idCommitment of the member
    function slash(uint256 idCommitment, address payable receiver, uint256[8] calldata proof)
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

        if (memberExists[idCommitment] == false) revert MemberNotRegistered(idCommitment);
        // check if member is registered
        if (stakedAmounts[idCommitment] == 0) {
            revert MemberHasNoStake(idCommitment);
        }

        if (!_verifyProof(idCommitment, receiver, proof)) {
            revert InvalidProof();
        }

        uint256 amountToTransfer = stakedAmounts[idCommitment];

        // delete member
        uint256 index = members[idCommitment];
        members[idCommitment] = 0;
        memberExists[idCommitment] = false;
        stakedAmounts[idCommitment] = 0;
        // TODO: remove from IMT

        // refund deposit
        withdrawalBalance[receiver] += amountToTransfer;

        emit MemberWithdrawn(idCommitment, index);
    }

    function _validateSlash(uint256 idCommitment, address payable receiver, uint256[8] calldata proof)
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

    function isValidCommitment(uint256 idCommitment) public view returns (bool) {
        return idCommitment != 0 && idCommitment < poseidonHasher.Q();
    }

    /// @dev Groth16 proof verification
    function _verifyProof(uint256 idCommitment, address receiver, uint256[8] calldata proof)
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

    function root() external view returns (uint256) {
        return imtData.root;
    }
}
