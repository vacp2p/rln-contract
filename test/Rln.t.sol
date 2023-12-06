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

        rln = new Rln(MEMBERSHIP_DEPOSIT, DEPTH, address(trueVerifier));
    }

    uint256 public constant MEMBERSHIP_DEPOSIT = 1_000_000_000_000_000;
    uint256 public constant DEPTH = 20;
    uint256 public constant SET_SIZE = 1_048_576;
    uint256[8] public zeroedProof = [0, 0, 0, 0, 0, 0, 0, 0];

    /// @dev Ensure that you can hash a value.
    function test__Constants() public {
        assertEq(rln.MEMBERSHIP_DEPOSIT(), MEMBERSHIP_DEPOSIT);
        assertEq(rln.DEPTH(), DEPTH);
        assertEq(rln.SET_SIZE(), SET_SIZE);
        assertEq(rln.deployedBlockNumber(), 1);
    }

    function test__ValidRegistration(uint256 idCommitment) public {
        vm.assume(rln.isValidCommitment(idCommitment));
        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        assertEq(rln.memberExists(idCommitment), true);
        assertEq(rln.members(idCommitment), 0);
    }

    function test__InvalidRegistration__DuplicateCommitment(uint256 idCommitment) public {
        vm.assume(rln.isValidCommitment(idCommitment));
        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        assertEq(rln.memberExists(idCommitment), true);
        assertEq(rln.members(idCommitment), 0);
        vm.expectRevert(DuplicateIdCommitment.selector);
        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment);
    }

    function test__InvalidRegistration__InvalidIdCommitment(uint256 idCommitment) public {
        vm.assume(!rln.isValidCommitment(idCommitment));
        vm.expectRevert(abi.encodeWithSelector(InvalidIdCommitment.selector, idCommitment));
        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment);
    }

    function test__InvalidRegistration__InsufficientDeposit(uint256 idCommitment) public {
        vm.assume(rln.isValidCommitment(idCommitment));
        uint256 badDepositAmount = MEMBERSHIP_DEPOSIT - 1;
        vm.expectRevert(abi.encodeWithSelector(InsufficientDeposit.selector, MEMBERSHIP_DEPOSIT, badDepositAmount));
        rln.register{ value: badDepositAmount }(idCommitment);
    }

    function test__InvalidRegistration__FullSet() public {
        Rln tempRln = new Rln(MEMBERSHIP_DEPOSIT, 2, address(rln.verifier()));
        uint256 setSize = tempRln.SET_SIZE();
        for (uint256 i = 1; i <= setSize; i++) {
            tempRln.register{ value: MEMBERSHIP_DEPOSIT }(i);
        }
        assertEq(tempRln.idCommitmentIndex(), 4);
        vm.expectRevert(FullTree.selector);
        tempRln.register{ value: MEMBERSHIP_DEPOSIT }(setSize + 1);
    }

    function test__ValidSlash(uint256 idCommitment, address payable to) public {
        // avoid precompiles, etc
        // TODO: wrap both of these in a single function
        assumePayable(to);
        assumeNotPrecompile(to);
        vm.assume(to != address(0));
        vm.assume(rln.isValidCommitment(idCommitment));

        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment);
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

        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        vm.expectRevert(abi.encodeWithSelector(InvalidReceiverAddress.selector, address(0)));
        rln.slash(idCommitment, payable(address(0)), zeroedProof);
    }

    function test__InvalidSlash__ToRlnAddress() public {
        uint256 idCommitment =
            19_014_214_495_641_488_759_237_505_126_948_346_942_972_912_379_615_652_741_039_992_445_865_937_985_820;
        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment);
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

        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment);
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

        Rln tempRln = new Rln(MEMBERSHIP_DEPOSIT, 2, address(falseVerifier));

        tempRln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment);

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
        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment);
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

        rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        rln.slash(idCommitment, to, zeroedProof);
        assertEq(rln.stakedAmounts(idCommitment), 0);
        assertEq(rln.members(idCommitment), 0);
        assertEq(rln.memberExists(idCommitment), false);

        vm.prank(to);
        rln.withdraw();
        assertEq(rln.withdrawalBalance(to), 0);
    }

    function test__root() public {
        uint256[] memory idCommitments = new uint256[](10);
        idCommitments[0] =
            19_143_711_682_366_759_980_911_001_457_853_255_795_836_264_632_723_844_153_354_310_748_778_748_156_460;
        idCommitments[1] =
            16_984_765_328_852_711_772_291_441_487_727_981_184_905_800_779_020_079_168_989_152_080_434_188_364_678;
        idCommitments[2] =
            10_972_315_136_095_845_343_447_418_815_139_813_428_649_316_683_283_020_632_475_608_655_814_722_712_541;
        idCommitments[3] =
            2_709_631_781_045_191_277_266_130_708_832_884_002_577_134_582_503_944_059_038_971_337_978_087_532_997;
        idCommitments[4] =
            8_255_654_132_980_945_447_086_418_574_686_169_461_187_805_238_257_784_695_584_517_016_324_877_809_505;
        idCommitments[5] =
            20_291_701_150_251_695_209_910_387_548_168_084_091_751_201_746_043_024_067_531_503_187_703_236_470_983;
        idCommitments[6] =
            11_817_872_986_033_932_471_261_438_074_921_403_500_882_957_864_164_537_515_599_299_873_089_437_746_577;
        idCommitments[7] =
            18_475_838_919_635_792_169_148_272_767_721_284_591_038_756_730_004_222_133_003_018_558_598_315_558_783;
        idCommitments[8] =
            10_612_118_277_928_165_031_660_389_522_171_737_855_229_037_400_929_675_201_853_245_490_188_277_695_983;
        idCommitments[9] =
            17_318_633_845_296_358_766_427_229_711_888_486_415_250_435_256_643_711_009_388_405_482_885_762_601_797;

        vm.pauseGasMetering();
        for (uint256 i = 0; i < idCommitments.length; i++) {
            rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitments[i]);
        }
        vm.resumeGasMetering();

        assertEq(
            rln.root(),
            5_210_724_218_081_541_877_101_688_952_118_136_930_297_124_697_603_087_561_558_225_712_176_057_209_122
        );
    }

    function test__paginationCommitments() public {
        uint256[] memory idCommitments = new uint256[](10);
        idCommitments[0] =
            19_143_711_682_366_759_980_911_001_457_853_255_795_836_264_632_723_844_153_354_310_748_778_748_156_460;
        idCommitments[1] =
            16_984_765_328_852_711_772_291_441_487_727_981_184_905_800_779_020_079_168_989_152_080_434_188_364_678;
        idCommitments[2] =
            10_972_315_136_095_845_343_447_418_815_139_813_428_649_316_683_283_020_632_475_608_655_814_722_712_541;
        idCommitments[3] =
            2_709_631_781_045_191_277_266_130_708_832_884_002_577_134_582_503_944_059_038_971_337_978_087_532_997;
        idCommitments[4] =
            8_255_654_132_980_945_447_086_418_574_686_169_461_187_805_238_257_784_695_584_517_016_324_877_809_505;
        idCommitments[5] =
            20_291_701_150_251_695_209_910_387_548_168_084_091_751_201_746_043_024_067_531_503_187_703_236_470_983;
        idCommitments[6] =
            11_817_872_986_033_932_471_261_438_074_921_403_500_882_957_864_164_537_515_599_299_873_089_437_746_577;
        idCommitments[7] =
            18_475_838_919_635_792_169_148_272_767_721_284_591_038_756_730_004_222_133_003_018_558_598_315_558_783;
        idCommitments[8] =
            10_612_118_277_928_165_031_660_389_522_171_737_855_229_037_400_929_675_201_853_245_490_188_277_695_983;
        idCommitments[9] =
            17_318_633_845_296_358_766_427_229_711_888_486_415_250_435_256_643_711_009_388_405_482_885_762_601_797;

        vm.pauseGasMetering();
        for (uint256 i = 0; i < idCommitments.length; i++) {
            rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitments[i]);
        }
        vm.resumeGasMetering();

        uint256[] memory commitments = rln.getCommitments(0, 10);
        assertEq(commitments.length, 10);
        for (uint256 i = 0; i < commitments.length; i++) {
            assertEq(commitments[i], idCommitments[i]);
        }
    }
}
