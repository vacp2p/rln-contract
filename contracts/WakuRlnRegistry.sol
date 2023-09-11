// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {WakuRln} from "./WakuRln.sol";
import {IPoseidonHasher} from "rln-contract/PoseidonHasher.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

error StorageAlreadyExists(address storageAddress);
error NoStorageContractAvailable();
error IncompatibleStorage();
error IncompatibleStorageIndex();

contract WakuRlnRegistry is OwnableUpgradeable, UUPSUpgradeable {
    uint16 public nextStorageIndex;
    mapping(uint16 => address) public storages;

    uint16 public usingStorageIndex = 0;

    IPoseidonHasher public poseidonHasher;

    event NewStorageContract(uint16 index, address storageAddress);

    modifier onlyUsableStorage() {
        if (usingStorageIndex >= nextStorageIndex) revert NoStorageContractAvailable();
        _;
    }

    function initialize(address _poseidonHasher) external initializer {
        poseidonHasher = IPoseidonHasher(_poseidonHasher);
        __Ownable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function _insertIntoStorageMap(address storageAddress) internal {
        storages[nextStorageIndex] = storageAddress;
        emit NewStorageContract(nextStorageIndex, storageAddress);
        nextStorageIndex += 1;
    }

    function registerStorage(address storageAddress) external onlyOwner {
        if (storages[nextStorageIndex] != address(0)) revert StorageAlreadyExists(storageAddress);
        WakuRln wakuRln = WakuRln(storageAddress);
        if (wakuRln.poseidonHasher() != poseidonHasher) revert IncompatibleStorage();
        if (wakuRln.contractIndex() != nextStorageIndex) revert IncompatibleStorageIndex();
        _insertIntoStorageMap(storageAddress);
    }

    function newStorage() external onlyOwner {
        WakuRln newStorageContract = new WakuRln(address(poseidonHasher), nextStorageIndex);
        _insertIntoStorageMap(address(newStorageContract));
    }

    function register(uint256[] calldata commitments) external onlyUsableStorage {
        // iteratively check if the storage contract is full, and increment the usingStorageIndex if it is
        while (true) {
            try WakuRln(storages[usingStorageIndex]).register(commitments) {
                break;
            } catch (bytes memory err) {
                if (keccak256(err) != keccak256(abi.encodeWithSignature("FullTree()"))) {
                    assembly {
                        revert(add(32, err), mload(err))
                    }
                    // when there are no further storage contracts available, revert
                } else if (usingStorageIndex + 1 >= nextStorageIndex) {
                    revert NoStorageContractAvailable();
                }
                usingStorageIndex += 1;
            }
        }
    }

    function register(uint16 storageIndex, uint256[] calldata commitments) external {
        if (storageIndex >= nextStorageIndex) revert NoStorageContractAvailable();
        WakuRln(storages[storageIndex]).register(commitments);
    }

    function register(uint16 storageIndex, uint256 commitment) external {
        if (storageIndex >= nextStorageIndex) revert NoStorageContractAvailable();
        // optimize the gas used below
        uint256[] memory commitments = new uint256[](1);
        commitments[0] = commitment;
        WakuRln(storages[storageIndex]).register(commitments);
    }

    function forceProgress() external onlyOwner onlyUsableStorage {
        if (storages[usingStorageIndex + 1] == address(0)) revert NoStorageContractAvailable();
        usingStorageIndex += 1;
    }
}
