// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../contracts/WakuRlnRegistry.sol";
import {PoseidonHasher} from "rln-contract/PoseidonHasher.sol";
import {DuplicateIdCommitment} from "rln-contract/RlnBase.sol";
import {noDuplicate} from "./utils.sol";
import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";

contract WakuRlnRegistryTest is Test {
    WakuRlnRegistry public wakuRlnRegistry;
    PoseidonHasher public poseidonHasher;

    function setUp() public {
        poseidonHasher = new PoseidonHasher();
        wakuRlnRegistry = new WakuRlnRegistry(address(poseidonHasher));
    }

    function test__NewStorage() public {
        wakuRlnRegistry.newStorage();
    }

    function test__RegisterStorage_BadIndex() public {
        wakuRlnRegistry.registerStorage(address(new WakuRln(address(poseidonHasher), 0)));
        address newStorage = address(new WakuRln(address(poseidonHasher), 0));
        vm.expectRevert(IncompatibleStorageIndex.selector);
        wakuRlnRegistry.registerStorage(newStorage);
    }

    function test__RegisterStorage_BadImpl() public {
        address newStorage = address(new WakuRln(address(new PoseidonHasher()), 0));
        vm.expectRevert(IncompatibleStorage.selector);
        wakuRlnRegistry.registerStorage(newStorage);
    }

    function test__Register(uint256[] calldata commitments) public {
        vm.assume(noDuplicate(commitments));
        wakuRlnRegistry.newStorage();
        wakuRlnRegistry.register(commitments);
    }

    function test__BadRegister(uint256[] calldata commitments) public {
        vm.assume(!noDuplicate(commitments));
        wakuRlnRegistry.newStorage();
        vm.expectRevert(DuplicateIdCommitment.selector);
        wakuRlnRegistry.register(commitments);
    }

    function test__forceProgression() public {
        wakuRlnRegistry.newStorage();
        wakuRlnRegistry.forceProgress();
        require(wakuRlnRegistry.usingStorageIndex() == 1);
    }
}
