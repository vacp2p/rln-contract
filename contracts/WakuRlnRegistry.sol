// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {WakuRln} from "./WakuRln.sol";
import {IPoseidonHasher} from "rln-contract/PoseidonHasher.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

error StorageAlreadyExists(address storageAddress);
error NoStorageContractAvailable();
error FailedToRegister(string reason);

contract WakuRlnRegistry is Ownable {
    uint16 public nextStorageIndex;
    mapping(uint16 => address) public storages;

    uint16 public usingStorageIndex = 0;

    IPoseidonHasher public immutable poseidonHasher;

    event NewStorageContract(uint16 index, address storageAddress);

    constructor(address _poseidonHasher) Ownable() {
        poseidonHasher = IPoseidonHasher(_poseidonHasher);
    }

    function _insertIntoStorageMap(address storageAddress) internal {
        storages[nextStorageIndex] = storageAddress;
        emit NewStorageContract(nextStorageIndex, storageAddress);
        nextStorageIndex += 1;
    }

    function registerStorage(address storageAddress) external onlyOwner {
        if (storages[nextStorageIndex] != address(0)) revert StorageAlreadyExists(storageAddress);
        _insertIntoStorageMap(storageAddress);
    }

    function newStorage() external onlyOwner {
        WakuRln newStorageContract = new WakuRln(address(poseidonHasher), nextStorageIndex);
        _insertIntoStorageMap(address(newStorageContract));
    }

    function register(uint256 commitment) external payable {
        if (usingStorageIndex >= nextStorageIndex) revert NoStorageContractAvailable();

        // iteratively check if the storage contract is full, and increment the usingStorageIndex if it is
        while (true) {
            try WakuRln(storages[usingStorageIndex]).register{value: msg.value}(commitment) {
                break;
            } catch Error(string memory reason) {
                if (keccak256(abi.encodePacked(reason)) != keccak256(abi.encodePacked("FullTree()"))) {
                    revert FailedToRegister(reason);
                }
                usingStorageIndex += 1;
            }
        }
    }
}
