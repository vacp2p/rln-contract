// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../contracts/WakuRlnRegistry.sol";
import {PoseidonHasher} from "rln-contract/PoseidonHasher.sol";
import {DuplicateIdCommitment, FullTree} from "rln-contract/RlnBase.sol";
import {noDuplicate} from "./utils.sol";
import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";

contract WakuRlnRegistryTest is Test {
    using stdStorage for StdStorage;

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

    function test__InvalidRegistration_Duplicate(uint256[] calldata commitments) public {
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

    function test__SingleRegistration(uint256 commitment) public {
        wakuRlnRegistry.newStorage();
        wakuRlnRegistry.register(0, commitment);
    }

    function test__InvalidSingleRegistration__NoStorageContract(uint256 commitment) public {
        wakuRlnRegistry.newStorage();
        vm.expectRevert(NoStorageContractAvailable.selector);
        wakuRlnRegistry.register(1, commitment);
    }

    function test__InvalidSingleRegistration__Duplicate(uint256 commitment) public {
        wakuRlnRegistry.newStorage();
        wakuRlnRegistry.register(0, commitment);
        vm.expectRevert(DuplicateIdCommitment.selector);
        wakuRlnRegistry.register(0, commitment);
    }

    function test__InvalidSingleRegistration__FullTree() public {
        vm.pauseGasMetering();
        wakuRlnRegistry.newStorage();
        WakuRln wakuRln = WakuRln(wakuRlnRegistry.storages(0));
        uint256 setSize = wakuRln.SET_SIZE();
        // setSize - 1 because RlnBase uses 1-indexing
        for (uint256 i = 0; i < setSize - 1; i++) {
            wakuRlnRegistry.register(0, i);
        }
        vm.resumeGasMetering();
        vm.expectRevert(FullTree.selector);
        wakuRlnRegistry.register(0, setSize);
    }

    function test__InvalidRegistration__NoStorageContract() public {
        vm.pauseGasMetering();
        wakuRlnRegistry.newStorage();
        address storageContract = wakuRlnRegistry.storages(0);
        uint256 setSize = WakuRln(storageContract).SET_SIZE();

        uint256[] memory commitments = new uint256[](setSize);
        for (uint256 i = 1; i < setSize; i++) {
            commitments[i] = i;
        }
        vm.expectRevert(NoStorageContractAvailable.selector);
        wakuRlnRegistry.register(commitments);
    }
}
