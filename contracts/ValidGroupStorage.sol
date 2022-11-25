// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@interep/contracts/Interep.sol";

interface IValidGroupStorage {
    function isValidGroup(uint256 groupId) external view returns (bool);

    function interep() external view returns (address);
}

contract ValidGroupStorage {
    mapping(uint256 => bool) public validGroups;

    Interep public interep;

    struct Group {
        bytes32 provider;
        bytes32 name;
    }

    constructor(address _interep, Group[] memory _groups) {
        interep = Interep(_interep);
        for (uint8 i = 0; i < _groups.length; i++) {
            uint256 groupId = uint256(
                keccak256(
                    abi.encodePacked(_groups[i].provider, _groups[i].name)
                )
            ) % SNARK_SCALAR_FIELD;
            (bytes32 provider, bytes32 name, , ) = interep.groups(groupId);
            if (provider == _groups[i].provider && name == _groups[i].name) {
                validGroups[groupId] = true;
            } else {
                revert("[ValidGroupStorage] Invalid group");
            }
        }
    }

    function isValidGroup(uint256 _groupId) public view returns (bool) {
        return validGroups[_groupId];
    }
}
