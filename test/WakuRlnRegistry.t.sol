// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../contracts/WakuRlnRegistry.sol";
import {PoseidonHasher} from "rln-contract/PoseidonHasher.sol";
import {DuplicateIdCommitment, FullTree} from "rln-contract/RlnBase.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {noDuplicate, noInvalidCommitment, isValidCommitment} from "./utils.sol";
import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";

contract WakuRlnRegistryTest is Test {
    using stdStorage for StdStorage;

    WakuRlnRegistry public wakuRlnRegistry;
    PoseidonHasher public poseidonHasher;

    function setUp() public {
        poseidonHasher = new PoseidonHasher();
        address implementation = address(new WakuRlnRegistry());
        bytes memory data = abi.encodeCall(WakuRlnRegistry.initialize, address(poseidonHasher));
        address proxy = address(new ERC1967Proxy(implementation, data));
        wakuRlnRegistry = WakuRlnRegistry(proxy);
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
        vm.assume(noInvalidCommitment(commitments, poseidonHasher.Q()));
        vm.assume(noDuplicate(commitments));
        wakuRlnRegistry.newStorage();
        wakuRlnRegistry.register(commitments);
    }

    function test__InvalidRegistration_Duplicate(uint256[] calldata commitments) public {
        vm.assume(noInvalidCommitment(commitments, poseidonHasher.Q()));
        vm.assume(!noDuplicate(commitments));
        wakuRlnRegistry.newStorage();
        vm.expectRevert(DuplicateIdCommitment.selector);
        wakuRlnRegistry.register(commitments);
    }

    function test__forceProgression() public {
        wakuRlnRegistry.newStorage();
        wakuRlnRegistry.newStorage();
        wakuRlnRegistry.forceProgress();
        assertEq(wakuRlnRegistry.usingStorageIndex(), 1);
        assertEq(wakuRlnRegistry.nextStorageIndex(), 2);
    }

    function test__SingleRegistration(uint256 commitment) public {
        vm.assume(isValidCommitment(commitment, poseidonHasher.Q()));
        wakuRlnRegistry.newStorage();
        wakuRlnRegistry.register(0, commitment);
    }

    function test__InvalidSingleRegistration__NoStorageContract(uint256 commitment) public {
        wakuRlnRegistry.newStorage();
        vm.assume(isValidCommitment(commitment, poseidonHasher.Q()));
        vm.expectRevert(NoStorageContractAvailable.selector);
        wakuRlnRegistry.register(1, commitment);
    }

    function test__InvalidSingleRegistration__Duplicate(uint256 commitment) public {
        vm.assume(isValidCommitment(commitment, poseidonHasher.Q()));
        wakuRlnRegistry.newStorage();
        wakuRlnRegistry.register(0, commitment);
        vm.expectRevert(DuplicateIdCommitment.selector);
        wakuRlnRegistry.register(0, commitment);
    }

    function test__InvalidSingleRegistration__FullTree() public {
        wakuRlnRegistry.newStorage();
        WakuRln wakuRln = WakuRln(wakuRlnRegistry.storages(0));
        uint256[] memory commitments = new uint256[](1);

        vm.mockCallRevert(
            address(wakuRln),
            abi.encodeWithSignature("register(uint256[])", commitments),
            abi.encodeWithSelector(FullTree.selector)
        );
        vm.expectRevert(FullTree.selector);
        wakuRlnRegistry.register(0, commitments[0]);
    }

    function test__InvalidRegistration__NoStorageContract() public {
        wakuRlnRegistry.newStorage();
        WakuRln wakuRln = WakuRln(wakuRlnRegistry.storages(0));

        uint256[] memory commitments = new uint256[](1);
        vm.mockCallRevert(
            address(wakuRln),
            abi.encodeWithSignature("register(uint256[])", commitments),
            abi.encodeWithSelector(FullTree.selector)
        );
        vm.expectRevert(NoStorageContractAvailable.selector);
        wakuRlnRegistry.register(commitments);
    }

    function test__forceProgression__NoStorageContract() public {
        vm.expectRevert(NoStorageContractAvailable.selector);
        wakuRlnRegistry.forceProgress();
        assertEq(wakuRlnRegistry.usingStorageIndex(), 0);
        assertEq(wakuRlnRegistry.nextStorageIndex(), 0);
    }
}
