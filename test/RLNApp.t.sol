// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "../contracts/PoseidonHasher.sol";
import "../contracts/RlnBase.sol";
import "./Verifier.sol";
import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";

contract RlnApp is RlnBase {
    uint256 public constant allowedIdCommitment =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    constructor(uint256 membershipDeposit, uint256 depth, address _poseidonHasher, address _verifier)
        RlnBase(membershipDeposit, depth, _poseidonHasher, _verifier)
    {}

    function _validateRegistration(uint256 idCommitment) internal pure override {
        if (idCommitment != allowedIdCommitment) revert FailedValidation();
    }

    function _validateSlash(uint256 idCommitment, address payable receiver, uint256[8] calldata proof)
        internal
        pure
        override
    {
        if (idCommitment == allowedIdCommitment) revert FailedValidation();
    }
}

contract RLNAppTest is Test {
    RlnApp public rlnApp;
    PoseidonHasher public poseidon;
    TrueVerifier public trueVerifier;

    uint256 public constant MEMBERSHIP_DEPOSIT = 1000000000000000;
    uint256 public constant DEPTH = 20;
    uint256 public constant SET_SIZE = 1048576;
    uint256[8] public zeroedProof = [0, 0, 0, 0, 0, 0, 0, 0];

    function setUp() public {
        poseidon = new PoseidonHasher();
        trueVerifier = new TrueVerifier();
        rlnApp = new RlnApp(MEMBERSHIP_DEPOSIT, DEPTH, address(poseidon), address(trueVerifier));
    }

    function test__Constants() public {
        // sanity checking
        assertEq(rlnApp.MEMBERSHIP_DEPOSIT(), MEMBERSHIP_DEPOSIT);
        assertEq(rlnApp.DEPTH(), DEPTH);
        assertEq(rlnApp.SET_SIZE(), SET_SIZE);
    }

    function test__InvalidRegistration(uint256 idCommitment) public {
        vm.assume(idCommitment != rlnApp.allowedIdCommitment());
        vm.expectRevert(FailedValidation.selector);
        rlnApp.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
    }

    function test__ValidRegistration() public {
        rlnApp.register{value: MEMBERSHIP_DEPOSIT}(rlnApp.allowedIdCommitment());
    }

    function test__InvalidSlash() public {
        uint256 allowedIdCommitment = rlnApp.allowedIdCommitment();
        rlnApp.register{value: MEMBERSHIP_DEPOSIT}(allowedIdCommitment);
        vm.expectRevert(FailedValidation.selector);
        rlnApp.slash(allowedIdCommitment, payable(address(this)), zeroedProof);
    }
}
