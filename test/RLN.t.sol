// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "../contracts/PoseidonHasher.sol";
import "../contracts/Rln.sol";
import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";

contract ArrayUnique {
    mapping(uint256 => bool) seen;

    constructor(uint256[] memory arr) {
        for (uint256 i = 0; i < arr.length; i++) {
            require(!seen[arr[i]], "ArrayUnique: duplicate value");
            seen[arr[i]] = true;
        }
    }

    // contract in construction goes around the assumePayable() check
    receive() external payable {}
}

function repeatElementIntoArray(
    uint256 length,
    address payable element
) pure returns (address payable[] memory) {
    address payable[] memory arr = new address payable[](length);
    for (uint256 i = 0; i < length; i++) {
        arr[i] = element;
    }
    return arr;
}

contract RLNTest is Test {
    using stdStorage for StdStorage;

    RLN public rln;
    PoseidonHasher public poseidon;

    uint256 public constant MEMBERSHIP_DEPOSIT = 1000000000000000;
    uint256 public constant DEPTH = 20;
    uint256 public constant SET_SIZE = 1048576;

    /// @dev Setup the testing environment.
    function setUp() public {
        poseidon = new PoseidonHasher();
        rln = new RLN(MEMBERSHIP_DEPOSIT, DEPTH, address(poseidon));
    }

    function isUniqueArray(uint256[] memory arr) internal returns (bool) {
        try new ArrayUnique(arr) {
            return true;
        } catch {
            return false;
        }
    }

    /// @dev Ensure that you can hash a value.
    function test__Constants() public {
        assertEq(rln.MEMBERSHIP_DEPOSIT(), MEMBERSHIP_DEPOSIT);
        assertEq(rln.DEPTH(), DEPTH);
        assertEq(rln.SET_SIZE(), SET_SIZE);
    }

    function test__ValidRegistration(uint256 idCommitment) public {
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        assertEq(rln.members(idCommitment), true);
    }

    function test__InvalidRegistration__DuplicateCommitment(
        uint256 idCommitment
    ) public {
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        assertEq(rln.members(idCommitment), true);
        vm.expectRevert(DuplicateIdCommitment.selector);
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
    }

    function test__InvalidRegistration__InsufficientDeposit(
        uint256 idCommitment
    ) public {
        uint256 badDepositAmount = MEMBERSHIP_DEPOSIT - 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                InsufficientDeposit.selector,
                MEMBERSHIP_DEPOSIT,
                badDepositAmount
            )
        );
        rln.register{value: badDepositAmount}(idCommitment);
    }

    function test__InvalidRegistration__FullSet(
        uint256 idCommitmentSeed
    ) public {
        vm.assume(idCommitmentSeed < 2 ** 255 - SET_SIZE);
        RLN tempRln = new RLN(
            MEMBERSHIP_DEPOSIT,
            2,
            address(rln.poseidonHasher())
        );
        uint256 setSize = tempRln.SET_SIZE();
        for (uint256 i = 0; i < setSize; i++) {
            tempRln.register{value: MEMBERSHIP_DEPOSIT}(idCommitmentSeed + i);
        }
        assertEq(tempRln.idCommitmentIndex(), 4);
        vm.expectRevert(FullBatch.selector);
        tempRln.register{value: MEMBERSHIP_DEPOSIT}(idCommitmentSeed + setSize);
    }

    function test__ValidBatchRegistration(
        uint256[] calldata idCommitments
    ) public {
        // assume that the array is unique, otherwise it triggers
        // a revert that has already been tested
        vm.assume(isUniqueArray(idCommitments) && idCommitments.length > 0);
        uint256 idCommitmentlen = idCommitments.length;
        rln.registerBatch{value: MEMBERSHIP_DEPOSIT * idCommitmentlen}(
            idCommitments
        );
        for (uint256 i = 0; i < idCommitmentlen; i++) {
            assertEq(rln.stakedAmounts(idCommitments[i]), MEMBERSHIP_DEPOSIT);
            assertEq(rln.members(idCommitments[i]), true);
        }
    }

    function test__InvalidBatchRegistration__FullSet(
        uint256 idCommitmentSeed
    ) public {
        vm.assume(idCommitmentSeed < 2 ** 255 - SET_SIZE);
        RLN tempRln = new RLN(MEMBERSHIP_DEPOSIT, 2, address(poseidon));
        uint256 setSize = tempRln.SET_SIZE();
        for (uint256 i = 0; i < setSize; i++) {
            tempRln.register{value: MEMBERSHIP_DEPOSIT}(idCommitmentSeed + i);
        }
        assertEq(tempRln.idCommitmentIndex(), 4);
        uint256[] memory idCommitments = new uint256[](1);
        idCommitments[0] = idCommitmentSeed + setSize;
        vm.expectRevert(FullBatch.selector);
        tempRln.registerBatch{value: MEMBERSHIP_DEPOSIT}(idCommitments);
    }

    function test__InvalidBatchRegistration__EmptyBatch() public {
        uint256[] memory idCommitments = new uint256[](0);
        vm.expectRevert(EmptyBatch.selector);
        rln.registerBatch{value: MEMBERSHIP_DEPOSIT}(idCommitments);
    }

    function test__InvalidBatchRegistration__InsufficientDeposit(
        uint256[] calldata idCommitments
    ) public {
        vm.assume(isUniqueArray(idCommitments) && idCommitments.length > 0);
        uint256 idCommitmentlen = idCommitments.length;
        uint256 goodDepositAmount = MEMBERSHIP_DEPOSIT * idCommitmentlen;
        uint256 badDepositAmount = goodDepositAmount - 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                InsufficientDeposit.selector,
                goodDepositAmount,
                badDepositAmount
            )
        );
        rln.registerBatch{value: badDepositAmount}(idCommitments);
    }

    function test__ValidWithdraw(
        uint256 idSecretHash,
        address payable to
    ) public {
        // avoid precompiles, etc
        // TODO: wrap both of these in a single function
        assumePayable(to);
        assumeNoPrecompiles(to);
        vm.assume(to != address(0));
        uint256 idCommitment = poseidon.hash(idSecretHash);

        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);

        uint256 balanceBefore = to.balance;
        rln.withdraw(idSecretHash, to);
        assertEq(rln.stakedAmounts(idCommitment), 0);
        assertEq(rln.members(idCommitment), false);
        assertEq(to.balance, balanceBefore + MEMBERSHIP_DEPOSIT);
    }

    function test__InvalidWithdraw__ToZeroAddress() public {
        uint256 idSecretHash = 19014214495641488759237505126948346942972912379615652741039992445865937985820;
        uint256 idCommitment = poseidon.hash(idSecretHash);
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidWithdrawalAddress.selector,
                address(0)
            )
        );
        rln.withdraw(idSecretHash, payable(address(0)));
    }

    function test__InvalidWithdraw__ToRlnAddress() public {
        uint256 idSecretHash = 19014214495641488759237505126948346942972912379615652741039992445865937985820;
        uint256 idCommitment = poseidon.hash(idSecretHash);
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidWithdrawalAddress.selector,
                address(rln)
            )
        );
        rln.withdraw(idSecretHash, payable(address(rln)));
    }

    function test__InvalidWithdraw__InvalidIdCommitment(
        uint256 idSecretHash
    ) public {
        uint256 idCommitment = poseidon.hash(idSecretHash);
        vm.expectRevert(
            abi.encodeWithSelector(MemberNotRegistered.selector, idCommitment)
        );
        rln.withdraw(idSecretHash, payable(address(this)));
    }

    // this shouldn't be possible, but just in case
    function test__InvalidWithdraw__NoStake(
        uint256 idSecretHash,
        address payable to
    ) public {
        // avoid precompiles, etc
        assumePayable(to);
        assumeNoPrecompiles(to);
        vm.assume(to != address(0));
        uint256 idCommitment = poseidon.hash(idSecretHash);

        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);

        rln.withdraw(idSecretHash, to);
        assertEq(rln.stakedAmounts(idCommitment), 0);
        assertEq(rln.members(idCommitment), false);

        // manually set members[idCommitment] to true using vm
        stdstore
            .target(address(rln))
            .sig("members(uint256)")
            .with_key(idCommitment)
            .depth(0)
            .checked_write(true);

        vm.expectRevert(
            abi.encodeWithSelector(MemberHasNoStake.selector, idCommitment)
        );
        rln.withdraw(idSecretHash, to);
    }

    function test__ValidBatchWithdraw(
        uint256[] calldata idSecretHashes,
        address payable to
    ) public {
        // avoid precompiles, etc
        assumePayable(to);
        assumeNoPrecompiles(to);
        vm.assume(isUniqueArray(idSecretHashes) && idSecretHashes.length > 0);
        vm.assume(to != address(0));
        uint256 idCommitmentlen = idSecretHashes.length;
        uint256[] memory idCommitments = new uint256[](idCommitmentlen);
        for (uint256 i = 0; i < idCommitmentlen; i++) {
            idCommitments[i] = poseidon.hash(idSecretHashes[i]);
        }

        rln.registerBatch{value: MEMBERSHIP_DEPOSIT * idCommitmentlen}(
            idCommitments
        );
        for (uint256 i = 0; i < idCommitmentlen; i++) {
            assertEq(rln.stakedAmounts(idCommitments[i]), MEMBERSHIP_DEPOSIT);
        }

        uint256 balanceBefore = to.balance;
        rln.withdrawBatch(
            idSecretHashes,
            repeatElementIntoArray(idSecretHashes.length, to)
        );
        for (uint256 i = 0; i < idCommitmentlen; i++) {
            assertEq(rln.stakedAmounts(idCommitments[i]), 0);
            assertEq(rln.members(idCommitments[i]), false);
        }
        assertEq(
            to.balance,
            balanceBefore + MEMBERSHIP_DEPOSIT * idCommitmentlen
        );
    }

    function test__InvalidBatchWithdraw__EmptyBatch() public {
        uint256[] memory idSecretHashes = new uint256[](0);
        address payable[] memory to = new address payable[](0);
        vm.expectRevert(EmptyBatch.selector);
        rln.withdrawBatch(idSecretHashes, to);
    }

    function test__InvalidBatchWithdraw__MismatchInputSize(
        uint256[] calldata idSecretHashes,
        address payable to
    ) public {
        assumePayable(to);
        assumeNoPrecompiles(to);
        vm.assume(isUniqueArray(idSecretHashes) && idSecretHashes.length > 0);
        vm.assume(to != address(0));

        uint256 numberOfReceivers = idSecretHashes.length + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                MismatchedBatchSize.selector,
                idSecretHashes.length,
                numberOfReceivers
            )
        );
        rln.withdrawBatch(
            idSecretHashes,
            repeatElementIntoArray(numberOfReceivers, to)
        );
    }
}
