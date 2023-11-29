// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "./RlnBase.sol";

contract Rln is RlnBase {
    constructor(
        uint256 membershipDeposit,
        uint256 depth,
        address _verifier
    )
        RlnBase(membershipDeposit, depth, _verifier)
    { }

    function _validateRegistration(uint256 idCommitment) internal pure override { }

    function _validateSlash(
        uint256 idCommitment,
        address payable receiver,
        uint256[8] calldata proof
    )
        internal
        pure
        override
    { }
}
