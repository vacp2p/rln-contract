// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "../contracts/PoseidonHasher.sol";
import "../contracts/Rln.sol";
import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";

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

    /// @dev Ensure that you can hash a value.
    function test__Constants() public {
        assertEq(rln.MEMBERSHIP_DEPOSIT(), MEMBERSHIP_DEPOSIT);
        assertEq(rln.DEPTH(), DEPTH);
        assertEq(rln.SET_SIZE(), SET_SIZE);
    }

    function test__ValidRegistration(uint256 idCommitment) public {
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        assertEq(rln.members(idCommitment), 1);
    }

    function test__InvalidRegistration__DuplicateCommitment(
        uint256 idCommitment
    ) public {
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        assertEq(rln.members(idCommitment), 1);
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
        uint256 setSize = tempRln.SET_SIZE() - 1;
        for (uint256 i = 0; i < setSize; i++) {
            tempRln.register{value: MEMBERSHIP_DEPOSIT}(idCommitmentSeed + i);
        }
        assertEq(tempRln.idCommitmentIndex(), 4);
        vm.expectRevert(FullTree.selector);
        tempRln.register{value: MEMBERSHIP_DEPOSIT}(idCommitmentSeed + setSize);
    }

    function test__ValidSlash(uint256 idSecretHash, address payable to) public {
        // avoid precompiles, etc
        // TODO: wrap both of these in a single function
        assumePayable(to);
        assumeNoPrecompiles(to);
        vm.assume(to != address(0));
        uint256 idCommitment = poseidon.hash(idSecretHash);

        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);

        uint256 balanceBefore = to.balance;
        rln.slash(idSecretHash, to);
        vm.prank(to);
        rln.withdraw();
        assertEq(rln.stakedAmounts(idCommitment), 0);
        assertEq(rln.members(idCommitment), 0);
        assertEq(to.balance, balanceBefore + MEMBERSHIP_DEPOSIT);
    }

    function test__InvalidSlash__ToZeroAddress() public {
        uint256 idSecretHash = 19014214495641488759237505126948346942972912379615652741039992445865937985820;
        uint256 idCommitment = poseidon.hash(idSecretHash);
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidReceiverAddress.selector, address(0))
        );
        rln.slash(idSecretHash, payable(address(0)));
    }

    function test__InvalidSlash__ToRlnAddress() public {
        uint256 idSecretHash = 19014214495641488759237505126948346942972912379615652741039992445865937985820;
        uint256 idCommitment = poseidon.hash(idSecretHash);
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidReceiverAddress.selector,
                address(rln)
            )
        );
        rln.slash(idSecretHash, payable(address(rln)));
    }

    function test__InvalidSlash__InvalidIdCommitment(
        uint256 idSecretHash
    ) public {
        uint256 idCommitment = poseidon.hash(idSecretHash);
        vm.expectRevert(
            abi.encodeWithSelector(MemberNotRegistered.selector, idCommitment)
        );
        rln.slash(idSecretHash, payable(address(this)));
    }

    // this shouldn't be possible, but just in case
    function test__InvalidSlash__NoStake(
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

        rln.slash(idSecretHash, to);
        assertEq(rln.stakedAmounts(idCommitment), 0);
        assertEq(rln.members(idCommitment), 0);

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
        rln.slash(idSecretHash, to);
    }

    function test__InvalidWithdraw__InsufficientWithdrawalBalance() public {
        vm.expectRevert(InsufficientWithdrawalBalance.selector);
        rln.withdraw();
    }

    function test__InvalidWithdraw__InsufficientContractBalance() public {
        uint256 idSecretHash = 19014214495641488759237505126948346942972912379615652741039992445865937985820;
        uint256 idCommitment = poseidon.hash(idSecretHash);
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        rln.slash(idSecretHash, payable(address(this)));
        assertEq(rln.stakedAmounts(idCommitment), 0);
        assertEq(rln.members(idCommitment), 0);

        vm.deal(address(rln), 0);
        vm.expectRevert(InsufficientContractBalance.selector);
        rln.withdraw();
    }

    function test__ValidWithdraw(address payable to) public {
        assumePayable(to);
        assumeNoPrecompiles(to);

        uint256 idSecretHash = 19014214495641488759237505126948346942972912379615652741039992445865937985820;
        uint256 idCommitment = poseidon.hash(idSecretHash);

        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        rln.slash(idSecretHash, to);
        assertEq(rln.stakedAmounts(idCommitment), 0);
        assertEq(rln.members(idCommitment), 0);

        vm.prank(to);
        rln.withdraw();
        assertEq(rln.withdrawalBalance(to), 0);
    }
}
