// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "../contracts/PoseidonHasher.sol";
import "../contracts/Rln.sol";
import "./Verifier.sol";
import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";

contract RlnTest is Test {
    using stdStorage for StdStorage;

    Rln public rln;
    PoseidonHasher public poseidon;
    TrueVerifier public trueVerifier;
    FalseVerifier public falseVerifier;

    uint256 public constant MEMBERSHIP_DEPOSIT = 1000000000000000;
    uint256 public constant DEPTH = 20;
    uint256 public constant SET_SIZE = 1048576;
    uint256[8] public zeroedProof = [0, 0, 0, 0, 0, 0, 0, 0];

    /// @dev Setup the testing environment.
    function setUp() public {
        poseidon = new PoseidonHasher();
        trueVerifier = new TrueVerifier();
        falseVerifier = new FalseVerifier();
        rln = new Rln(MEMBERSHIP_DEPOSIT, DEPTH, address(poseidon), address(trueVerifier));
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

    function test__InvalidRegistration__DuplicateCommitment(uint256 idCommitment) public {
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        assertEq(rln.members(idCommitment), 1);
        vm.expectRevert(DuplicateIdCommitment.selector);
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
    }

    function test__InvalidRegistration__InsufficientDeposit(uint256 idCommitment) public {
        uint256 badDepositAmount = MEMBERSHIP_DEPOSIT - 1;
        vm.expectRevert(abi.encodeWithSelector(InsufficientDeposit.selector, MEMBERSHIP_DEPOSIT, badDepositAmount));
        rln.register{value: badDepositAmount}(idCommitment);
    }

    function test__InvalidRegistration__FullSet(uint256 idCommitmentSeed) public {
        vm.assume(idCommitmentSeed < 2 ** 255 - SET_SIZE);
        Rln tempRln = new Rln(
            MEMBERSHIP_DEPOSIT,
            2,
            address(rln.poseidonHasher()),
            address(rln.verifier())
        );
        uint256 setSize = tempRln.SET_SIZE() - 1;
        for (uint256 i = 0; i < setSize; i++) {
            tempRln.register{value: MEMBERSHIP_DEPOSIT}(idCommitmentSeed + i);
        }
        assertEq(tempRln.idCommitmentIndex(), 4);
        vm.expectRevert(FullTree.selector);
        tempRln.register{value: MEMBERSHIP_DEPOSIT}(idCommitmentSeed + setSize);
    }

    function test__ValidSlash(uint256 idCommitment, address payable to) public {
        // avoid precompiles, etc
        // TODO: wrap both of these in a single function
        assumePayable(to);
        assumeNoPrecompiles(to);
        vm.assume(to != address(0));

        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);

        uint256 balanceBefore = to.balance;
        rln.slash(idCommitment, to, zeroedProof);
        vm.prank(to);
        rln.withdraw();
        assertEq(rln.stakedAmounts(idCommitment), 0);
        assertEq(rln.members(idCommitment), 0);
        assertEq(to.balance, balanceBefore + MEMBERSHIP_DEPOSIT);
    }

    function test__InvalidSlash__ToZeroAddress() public {
        uint256 idCommitment = 9014214495641488759237505126948346942972912379615652741039992445865937985820;

        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        vm.expectRevert(abi.encodeWithSelector(InvalidReceiverAddress.selector, address(0)));
        rln.slash(idCommitment, payable(address(0)), zeroedProof);
    }

    function test__InvalidSlash__ToRlnAddress() public {
        uint256 idCommitment = 19014214495641488759237505126948346942972912379615652741039992445865937985820;
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        vm.expectRevert(abi.encodeWithSelector(InvalidReceiverAddress.selector, address(rln)));
        rln.slash(idCommitment, payable(address(rln)), zeroedProof);
    }

    function test__InvalidSlash__InvalidIdCommitment(uint256 idCommitment) public {
        vm.expectRevert(abi.encodeWithSelector(MemberNotRegistered.selector, idCommitment));
        rln.slash(idCommitment, payable(address(this)), zeroedProof);
    }

    // this shouldn't be possible, but just in case
    function test__InvalidSlash__NoStake(uint256 idCommitment, address payable to) public {
        // avoid precompiles, etc
        assumePayable(to);
        assumeNoPrecompiles(to);
        vm.assume(to != address(0));

        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);

        rln.slash(idCommitment, to, zeroedProof);
        assertEq(rln.stakedAmounts(idCommitment), 0);
        assertEq(rln.members(idCommitment), 0);

        // manually set members[idCommitment] to true using vm
        stdstore.target(address(rln)).sig("members(uint256)").with_key(idCommitment).depth(0).checked_write(true);

        vm.expectRevert(abi.encodeWithSelector(MemberHasNoStake.selector, idCommitment));
        rln.slash(idCommitment, to, zeroedProof);
    }

    function test__InvalidSlash__InvalidProof() public {
        uint256 idCommitment = 19014214495641488759237505126948346942972912379615652741039992445865937985820;

        Rln tempRln = new Rln(
            MEMBERSHIP_DEPOSIT,
            2,
            address(rln.poseidonHasher()),
            address(falseVerifier)
        );

        tempRln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);

        vm.expectRevert(InvalidProof.selector);
        tempRln.slash(idCommitment, payable(address(this)), zeroedProof);
    }

    function test__InvalidWithdraw__InsufficientWithdrawalBalance() public {
        vm.expectRevert(InsufficientWithdrawalBalance.selector);
        rln.withdraw();
    }

    function test__InvalidWithdraw__InsufficientContractBalance() public {
        uint256 idCommitment = 19014214495641488759237505126948346942972912379615652741039992445865937985820;
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        rln.slash(idCommitment, payable(address(this)), zeroedProof);
        assertEq(rln.stakedAmounts(idCommitment), 0);
        assertEq(rln.members(idCommitment), 0);

        vm.deal(address(rln), 0);
        vm.expectRevert(InsufficientContractBalance.selector);
        rln.withdraw();
    }

    function test__ValidWithdraw(address payable to) public {
        assumePayable(to);
        assumeNoPrecompiles(to);

        uint256 idCommitment = 19014214495641488759237505126948346942972912379615652741039992445865937985820;

        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        rln.slash(idCommitment, to, zeroedProof);
        assertEq(rln.stakedAmounts(idCommitment), 0);
        assertEq(rln.members(idCommitment), 0);

        vm.prank(to);
        rln.withdraw();
        assertEq(rln.withdrawalBalance(to), 0);
    }
}
