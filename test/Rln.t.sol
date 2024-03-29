// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { Test, console } from "forge-std/Test.sol";
import "forge-std/StdCheats.sol";

import { TrueVerifier, FalseVerifier } from "./mocks/VerifierMock.sol";

import { Deploy } from "../script/Deploy.s.sol";
import { DeploymentConfig } from "../script/DeploymentConfig.s.sol";
import "../src/Rln.sol";

contract RlnTest is Test {
    using stdStorage for StdStorage;

    Rln internal rln;
    TrueVerifier internal trueVerifier;
    FalseVerifier internal falseVerifier;

    function setUp() public virtual {
        trueVerifier = new TrueVerifier();
        falseVerifier = new FalseVerifier();

        rln = new Rln(MEMBERSHIP_DEPOSIT, DEPTH, MAX_MESSAGE_LIMIT, address(trueVerifier));
    }

    uint256 public constant MEMBERSHIP_DEPOSIT = 1_000_000_000_000_000;
    uint256 public constant MAX_MESSAGE_LIMIT = 20;
    uint256 public constant DEPTH = 20;
    uint256 public constant SET_SIZE = 1_048_576;
    uint256[8] public zeroedProof = [0, 0, 0, 0, 0, 0, 0, 0];

    /// @dev Ensure that you can hash a value.
    function test__Constants() public {
        assertEq(rln.MEMBERSHIP_DEPOSIT(), MEMBERSHIP_DEPOSIT);
        assertEq(rln.DEPTH(), DEPTH);
        assertEq(rln.SET_SIZE(), SET_SIZE);
        assertEq(rln.MAX_MESSAGE_LIMIT(), MAX_MESSAGE_LIMIT);
        assertEq(rln.deployedBlockNumber(), 1);
    }

    function test__ValidRegistration(uint256 idCommitment) public {
        vm.assume(rln.isValidCommitment(idCommitment));
        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment, 1);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        assertEq(rln.memberExists(idCommitment), true);
        assertEq(rln.members(idCommitment), 0);
        assertEq(rln.userMessageLimits(idCommitment), 1);
    }

    function test__InvalidRegistration__DuplicateCommitment(uint256 idCommitment) public {
        vm.assume(rln.isValidCommitment(idCommitment));
        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment, 1);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        assertEq(rln.memberExists(idCommitment), true);
        assertEq(rln.members(idCommitment), 0);
        assertEq(rln.userMessageLimits(idCommitment), 1);
        vm.expectRevert(DuplicateIdCommitment.selector);
        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment, 1);
    }

    function test__InvalidRegistration__InvalidIdCommitment(uint256 idCommitment) public {
        vm.assume(!rln.isValidCommitment(idCommitment));
        vm.expectRevert(abi.encodeWithSelector(InvalidIdCommitment.selector, idCommitment));
        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment, 1);
    }

    function test__InvalidRegistration__InvalidUserMessageLimit() public {
        uint256 idCommitment =
            9_014_214_495_641_488_759_237_505_126_948_346_942_972_912_379_615_652_741_039_992_445_865_937_985_820;
        vm.assume(rln.isValidCommitment(idCommitment));
        vm.expectRevert(abi.encodeWithSelector(InvalidUserMessageLimit.selector, 0));
        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment, 0);
    }

    function test__InvalidRegistration__MaxUserMessageLimit() public {
        uint256 idCommitment =
            9_014_214_495_641_488_759_237_505_126_948_346_942_972_912_379_615_652_741_039_992_445_865_937_985_820;
        vm.assume(rln.isValidCommitment(idCommitment));
        vm.expectRevert(abi.encodeWithSelector(InvalidUserMessageLimit.selector, MAX_MESSAGE_LIMIT + 1));
        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment, MAX_MESSAGE_LIMIT + 1);
    }

    function test__InvalidRegistration__InsufficientDeposit(uint256 idCommitment) public {
        vm.assume(rln.isValidCommitment(idCommitment));
        uint256 badDepositAmount = MEMBERSHIP_DEPOSIT - 1;
        vm.expectRevert(abi.encodeWithSelector(InsufficientDeposit.selector, MEMBERSHIP_DEPOSIT, badDepositAmount));
        rln.register{ value: badDepositAmount }(idCommitment, 1);
    }

    function test__InvalidRegistration__FullSet() public {
        Rln tempRln = new Rln(MEMBERSHIP_DEPOSIT, 2, MAX_MESSAGE_LIMIT, address(rln.verifier()));
        uint256 setSize = tempRln.SET_SIZE();
        for (uint256 i = 1; i <= setSize; i++) {
            tempRln.register{ value: MEMBERSHIP_DEPOSIT }(i, 1);
        }
        assertEq(tempRln.idCommitmentIndex(), 4);
        vm.expectRevert(FullTree.selector);
        tempRln.register{ value: MEMBERSHIP_DEPOSIT }(setSize + 1, 1);
    }

    function test__ValidSlash(uint256 idCommitment, address payable to) public {
        // avoid precompiles, etc
        // TODO: wrap both of these in a single function
        assumePayable(to);
        assumeNotPrecompile(to);
        vm.assume(to != address(0));
        vm.assume(rln.isValidCommitment(idCommitment));

        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment, 1);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);

        uint256 balanceBefore = to.balance;
        rln.slash(idCommitment, to, zeroedProof);
        assertEq(rln.withdrawalBalance(to), MEMBERSHIP_DEPOSIT);
        vm.prank(to);
        rln.withdraw();
        assertEq(rln.stakedAmounts(idCommitment), 0);
        assertEq(rln.members(idCommitment), 0);
        assertEq(rln.withdrawalBalance(to), 0);
        assertEq(to.balance, balanceBefore + MEMBERSHIP_DEPOSIT);
    }

    function test__InvalidSlash__ToZeroAddress() public {
        uint256 idCommitment =
            9_014_214_495_641_488_759_237_505_126_948_346_942_972_912_379_615_652_741_039_992_445_865_937_985_820;

        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment, 1);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        vm.expectRevert(abi.encodeWithSelector(InvalidReceiverAddress.selector, address(0)));
        rln.slash(idCommitment, payable(address(0)), zeroedProof);
    }

    function test__InvalidSlash__ToRlnAddress() public {
        uint256 idCommitment =
            19_014_214_495_641_488_759_237_505_126_948_346_942_972_912_379_615_652_741_039_992_445_865_937_985_820;
        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment, 1);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        vm.expectRevert(abi.encodeWithSelector(InvalidReceiverAddress.selector, address(rln)));
        rln.slash(idCommitment, payable(address(rln)), zeroedProof);
    }

    function test__InvalidSlash__MemberNotRegistered(uint256 idCommitment) public {
        vm.assume(rln.isValidCommitment(idCommitment));
        vm.expectRevert(abi.encodeWithSelector(MemberNotRegistered.selector, idCommitment));
        rln.slash(idCommitment, payable(address(this)), zeroedProof);
    }

    // this shouldn't be possible, but just in case
    function test__InvalidSlash__NoStake(uint256 idCommitment, address payable to) public {
        // avoid precompiles, etc
        assumePayable(to);
        assumeNotPrecompile(to);
        vm.assume(to != address(0));
        vm.assume(rln.isValidCommitment(idCommitment));

        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment, 1);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);

        rln.slash(idCommitment, to, zeroedProof);
        assertEq(rln.stakedAmounts(idCommitment), 0);
        assertEq(rln.members(idCommitment), 0);

        // manually set members[idCommitment] to true using vm
        stdstore.target(address(rln)).sig("memberExists(uint256)").with_key(idCommitment).depth(0).checked_write(true);

        vm.expectRevert(abi.encodeWithSelector(MemberHasNoStake.selector, idCommitment));
        rln.slash(idCommitment, to, zeroedProof);
    }

    function test__InvalidSlash__InvalidProof() public {
        uint256 idCommitment =
            19_014_214_495_641_488_759_237_505_126_948_346_942_972_912_379_615_652_741_039_992_445_865_937_985_820;

        Rln tempRln = new Rln(MEMBERSHIP_DEPOSIT, 2, MAX_MESSAGE_LIMIT, address(falseVerifier));

        tempRln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment, 1);

        vm.expectRevert(InvalidProof.selector);
        tempRln.slash(idCommitment, payable(address(this)), zeroedProof);
    }

    function test__InvalidWithdraw__InsufficientWithdrawalBalance() public {
        vm.expectRevert(InsufficientWithdrawalBalance.selector);
        rln.withdraw();
    }

    function test__InvalidWithdraw__InsufficientContractBalance() public {
        uint256 idCommitment =
            19_014_214_495_641_488_759_237_505_126_948_346_942_972_912_379_615_652_741_039_992_445_865_937_985_820;
        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment, 1);
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
        assumeNotPrecompile(to);
        vm.assume(to != address(0));

        uint256 idCommitment =
            19_014_214_495_641_488_759_237_505_126_948_346_942_972_912_379_615_652_741_039_992_445_865_937_985_820;

        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment, 1);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        rln.slash(idCommitment, to, zeroedProof);
        assertEq(rln.stakedAmounts(idCommitment), 0);
        assertEq(rln.members(idCommitment), 0);
        assertEq(rln.memberExists(idCommitment), false);

        vm.prank(to);
        rln.withdraw();
        assertEq(rln.withdrawalBalance(to), 0);
    }
}
