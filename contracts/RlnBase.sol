// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {PoseidonHasher} from "./PoseidonHasher.sol";
import {IVerifier} from "./IVerifier.sol";

import "forge-std/console.sol";

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

    /// @notice the index to membership status mapping
    /// maps from index to idCommitment
    mapping(uint256 => uint256) public indexToIdCommitment;

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
        indexToIdCommitment[idCommitmentIndex] = idCommitment;
        memberExists[idCommitment] = true;
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
        indexToIdCommitment[index] = 0;
        memberExists[idCommitment] = false;
        stakedAmounts[idCommitment] = 0;

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

    /// Hashes a value using the Poseidon hasher
    /// NOTE: The variant of Poseidon we use accepts only 1 input, assume n=2
    /// @param inputs The values to hash
    function hash(uint256[2] memory inputs) internal view returns (uint256) {
        return poseidonHasher.hash(inputs);
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

    uint256 public constant Z_0 = 0;
    uint256 public constant Z_1 = 14744269619966411208579211824598458697587494354926760081771325075741142829156;
    uint256 public constant Z_2 = 7423237065226347324353380772367382631490014989348495481811164164159255474657;
    uint256 public constant Z_3 = 11286972368698509976183087595462810875513684078608517520839298933882497716792;
    uint256 public constant Z_4 = 3607627140608796879659380071776844901612302623152076817094415224584923813162;
    uint256 public constant Z_5 = 19712377064642672829441595136074946683621277828620209496774504837737984048981;
    uint256 public constant Z_6 = 20775607673010627194014556968476266066927294572720319469184847051418138353016;
    uint256 public constant Z_7 = 3396914609616007258851405644437304192397291162432396347162513310381425243293;
    uint256 public constant Z_8 = 21551820661461729022865262380882070649935529853313286572328683688269863701601;
    uint256 public constant Z_9 = 6573136701248752079028194407151022595060682063033565181951145966236778420039;
    uint256 public constant Z_10 = 12413880268183407374852357075976609371175688755676981206018884971008854919922;
    uint256 public constant Z_11 = 14271763308400718165336499097156975241954733520325982997864342600795471836726;
    uint256 public constant Z_12 = 20066985985293572387227381049700832219069292839614107140851619262827735677018;
    uint256 public constant Z_13 = 9394776414966240069580838672673694685292165040808226440647796406499139370960;
    uint256 public constant Z_14 = 11331146992410411304059858900317123658895005918277453009197229807340014528524;
    uint256 public constant Z_15 = 15819538789928229930262697811477882737253464456578333862691129291651619515538;
    uint256 public constant Z_16 = 19217088683336594659449020493828377907203207941212636669271704950158751593251;
    uint256 public constant Z_17 = 21035245323335827719745544373081896983162834604456827698288649288827293579666;
    uint256 public constant Z_18 = 6939770416153240137322503476966641397417391950902474480970945462551409848591;
    uint256 public constant Z_19 = 10941962436777715901943463195175331263348098796018438960955633645115732864202;

    function defaultZero(uint8 index) public pure returns (uint256) {
        if (index == 0) return Z_0;
        if (index == 1) return Z_1;
        if (index == 2) return Z_2;
        if (index == 3) return Z_3;
        if (index == 4) return Z_4;
        if (index == 5) return Z_5;
        if (index == 6) return Z_6;
        if (index == 7) return Z_7;
        if (index == 8) return Z_8;
        if (index == 9) return Z_9;
        if (index == 10) return Z_10;
        if (index == 11) return Z_11;
        if (index == 12) return Z_12;
        if (index == 13) return Z_13;
        if (index == 14) return Z_14;
        if (index == 15) return Z_15;
        if (index == 16) return Z_16;
        if (index == 17) return Z_17;
        if (index == 18) return Z_18;
        if (index == 19) return Z_19;
        revert("defaultZero bad index");
    }

    function computeRoot() external view returns (uint256) {
        if (idCommitmentIndex == 0) return defaultZero(0);
        uint256 index = idCommitmentIndex - 1;

        uint256[] memory levels = new uint256[](DEPTH + 1);

        if (index & 1 == 0) {
            levels[0] = indexToIdCommitment[index];
        } else {
            levels[0] = defaultZero(0);
        }

        for (uint8 i = 0; i < DEPTH;) {
            if (index & 1 == 0) {
                levels[i + 1] = hash([levels[i], defaultZero(i)]);
            } else {
                uint256 levelCount = (idCommitmentIndex) >> (i + 1);
                if (levelCount > index >> 1) {
                    uint256 parent = indexToIdCommitment[index + 1];
                    levels[i + 1] = parent;
                } else {
                    uint256 sibling = indexToIdCommitment[index - 1];
                    levels[i + 1] = hash([sibling, levels[i]]);
                }
            }
            unchecked {
                index >>= 1;
                i++;
            }
        }
        return levels[DEPTH];
    }
}
