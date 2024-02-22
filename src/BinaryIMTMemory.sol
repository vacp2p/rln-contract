// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { PoseidonT3 } from "poseidon-solidity/PoseidonT3.sol";

// stripped down version of
// solhint-disable-next-line max-line-length
// https://github.com/privacy-scaling-explorations/zk-kit/blob/718a5c2fa0f6cd577cee3fd08373609ac985d3bb/packages/imt.sol/contracts/internal/InternalBinaryIMT.sol
// that allows getting the root of the rln tree without expensive storage reads/writes
struct BinaryIMTMemoryData {
    uint256 root; // Root hash of the tree.
    uint256 numberOfLeaves; // Number of leaves of the tree.
    uint256 depth; // Depth of the tree.
}

/// @title In memory Incremental binary Merkle tree Root calculator
/// @dev This helper library allows to calculate the root hash of the tree without using storage
library BinaryIMTMemory {
    uint8 public constant MAX_DEPTH = 20;
    uint256 public constant SNARK_SCALAR_FIELD =
        21_888_242_871_839_275_222_246_405_745_257_275_088_548_364_400_416_034_343_698_204_186_575_808_495_617;

    uint256 public constant Z_0 = 0;
    uint256 public constant Z_1 =
        14_744_269_619_966_411_208_579_211_824_598_458_697_587_494_354_926_760_081_771_325_075_741_142_829_156;
    uint256 public constant Z_2 =
        7_423_237_065_226_347_324_353_380_772_367_382_631_490_014_989_348_495_481_811_164_164_159_255_474_657;
    uint256 public constant Z_3 =
        11_286_972_368_698_509_976_183_087_595_462_810_875_513_684_078_608_517_520_839_298_933_882_497_716_792;
    uint256 public constant Z_4 =
        3_607_627_140_608_796_879_659_380_071_776_844_901_612_302_623_152_076_817_094_415_224_584_923_813_162;
    uint256 public constant Z_5 =
        19_712_377_064_642_672_829_441_595_136_074_946_683_621_277_828_620_209_496_774_504_837_737_984_048_981;
    uint256 public constant Z_6 =
        20_775_607_673_010_627_194_014_556_968_476_266_066_927_294_572_720_319_469_184_847_051_418_138_353_016;
    uint256 public constant Z_7 =
        3_396_914_609_616_007_258_851_405_644_437_304_192_397_291_162_432_396_347_162_513_310_381_425_243_293;
    uint256 public constant Z_8 =
        21_551_820_661_461_729_022_865_262_380_882_070_649_935_529_853_313_286_572_328_683_688_269_863_701_601;
    uint256 public constant Z_9 =
        6_573_136_701_248_752_079_028_194_407_151_022_595_060_682_063_033_565_181_951_145_966_236_778_420_039;
    uint256 public constant Z_10 =
        12_413_880_268_183_407_374_852_357_075_976_609_371_175_688_755_676_981_206_018_884_971_008_854_919_922;
    uint256 public constant Z_11 =
        14_271_763_308_400_718_165_336_499_097_156_975_241_954_733_520_325_982_997_864_342_600_795_471_836_726;
    uint256 public constant Z_12 =
        20_066_985_985_293_572_387_227_381_049_700_832_219_069_292_839_614_107_140_851_619_262_827_735_677_018;
    uint256 public constant Z_13 =
        9_394_776_414_966_240_069_580_838_672_673_694_685_292_165_040_808_226_440_647_796_406_499_139_370_960;
    uint256 public constant Z_14 =
        11_331_146_992_410_411_304_059_858_900_317_123_658_895_005_918_277_453_009_197_229_807_340_014_528_524;
    uint256 public constant Z_15 =
        15_819_538_789_928_229_930_262_697_811_477_882_737_253_464_456_578_333_862_691_129_291_651_619_515_538;
    uint256 public constant Z_16 =
        19_217_088_683_336_594_659_449_020_493_828_377_907_203_207_941_212_636_669_271_704_950_158_751_593_251;
    uint256 public constant Z_17 =
        21_035_245_323_335_827_719_745_544_373_081_896_983_162_834_604_456_827_698_288_649_288_827_293_579_666;
    uint256 public constant Z_18 =
        6_939_770_416_153_240_137_322_503_476_966_641_397_417_391_950_902_474_480_970_945_462_551_409_848_591;
    uint256 public constant Z_19 =
        10_941_962_436_777_715_901_943_463_195_175_331_263_348_098_796_018_438_960_955_633_645_115_732_864_202;
    uint256 public constant Z_20 =
        15_019_797_232_609_675_441_998_260_052_101_280_400_536_945_603_062_888_308_240_081_994_073_687_793_470;

    // solhint-disable-next-line code-complexity
    function defaultZero(uint256 index) public pure returns (uint256) {
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
        if (index == 20) return Z_20;
        revert("IncrementalBinaryTree: defaultZero bad index");
    }

    /// @dev Computes the root of the tree given the leaves.
    /// @param self: Tree data.
    /// @param leaves: Leaves in the tree
    function calcRoot(
        BinaryIMTMemoryData memory self,
        uint256 depth,
        uint256[] memory leaves
    )
        public
        pure
        returns (uint256)
    {
        uint256[2][] memory lastSubtrees = new uint256[2][](depth);

        for (uint8 j = 0; j < leaves.length; j++) {
            uint256 index = self.numberOfLeaves;
            uint256 hash = leaves[j];
            for (uint8 i = 0; i < depth;) {
                if (index & 1 == 0) {
                    lastSubtrees[i] = [hash, defaultZero(i)];
                } else {
                    if (i > 0) {
                        lastSubtrees[i][0] = lastSubtrees[i][0];
                    }
                    lastSubtrees[i][1] = hash;
                }
                hash = PoseidonT3.hash(lastSubtrees[i]);
                index >>= 1;
                unchecked {
                    ++i;
                }
            }
            self.root = hash;
            self.numberOfLeaves += 1;
        }
        return self.root;
    }
}
