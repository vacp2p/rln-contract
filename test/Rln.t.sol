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

    function test__root() public {
        uint256[] memory idCommitments = new uint256[](20);
        idCommitments[0] =
            20_247_267_680_401_005_346_274_578_821_543_189_710_026_653_465_287_274_953_093_311_729_853_323_564_993;
        idCommitments[1] =
            17_156_989_550_607_148_435_222_849_763_909_493_047_059_958_780_520_493_064_916_232_951_463_175_150_232;
        idCommitments[2] =
            19_407_226_803_745_267_103_608_182_642_384_012_885_199_367_851_532_943_079_325_397_211_138_049_136_059;
        idCommitments[3] =
            10_843_159_696_774_792_948_443_591_344_995_886_877_305_260_668_485_645_797_849_607_534_704_262_422_614;
        idCommitments[4] =
            15_752_850_412_139_811_972_088_845_441_337_097_950_281_706_419_552_473_737_567_891_612_825_963_973_284;
        idCommitments[5] =
            4_519_863_328_057_168_189_298_631_669_175_527_040_337_788_759_018_171_546_425_601_895_038_423_288_676;
        idCommitments[6] =
            20_627_603_771_378_896_374_342_882_478_326_393_493_797_675_723_581_644_707_860_442_401_185_847_711_606;
        idCommitments[7] =
            15_154_129_217_924_019_401_315_002_167_199_740_344_372_362_483_772_641_456_490_923_254_762_406_760_783;
        idCommitments[8] =
            3_015_981_008_465_776_671_380_535_237_073_859_585_910_422_946_858_408_575_400_681_261_858_382_907_193;
        idCommitments[9] =
            224_054_746_800_950_089_703_161_552_547_065_908_637_798_421_998_793_333_020_881_640_418_719_302_913;
        idCommitments[10] =
            11_312_879_727_214_499_351_626_352_295_289_579_557_712_856_071_583_396_259_776_980_542_429_783_930_998;
        idCommitments[11] =
            12_465_380_480_462_031_386_424_255_751_937_172_435_855_917_781_265_550_857_371_960_580_299_590_023_804;
        idCommitments[12] =
            10_532_759_670_323_423_548_160_832_454_733_716_332_118_269_972_426_626_732_736_793_882_239_669_630_595;
        idCommitments[13] =
            5_363_974_916_211_877_996_441_994_123_101_828_809_420_707_174_378_417_661_497_477_404_431_739_760_929;
        idCommitments[14] =
            16_136_233_734_969_897_677_998_619_926_295_968_066_529_681_582_940_418_030_166_845_477_723_796_227_875;
        idCommitments[15] =
            19_482_780_886_140_959_996_233_254_660_604_422_414_723_443_061_405_603_031_287_446_813_590_162_051_267;
        idCommitments[16] =
            10_229_567_829_413_302_626_314_791_721_752_882_914_790_767_942_876_437_744_444_365_366_344_582_485_888;
        idCommitments[17] =
            13_243_196_170_549_739_682_068_942_953_623_914_146_349_583_225_049_284_668_843_899_390_874_999_176_721;
        idCommitments[18] =
            10_860_831_981_296_153_559_626_134_370_426_776_811_139_720_916_552_827_925_568_614_682_099_174_768_128;
        idCommitments[19] =
            18_217_334_211_520_937_958_971_536_517_166_530_749_184_547_628_672_204_353_760_850_739_130_586_503_124;

        vm.pauseGasMetering();
        for (uint256 i = 0; i < idCommitments.length; i++) {
            // default 1 message limit
            rln.register{ value: MEMBERSHIP_DEPOSIT }(idCommitments[i], 1);
        }
        vm.resumeGasMetering();

        assertEq(
            rln.root(),
            11_878_758_533_199_576_052_254_314_452_742_479_731_463_159_441_555_548_457_402_116_093_772_672_905_513
        );
    }
}
