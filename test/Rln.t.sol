// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "../contracts/PoseidonHasher.sol";
import "../contracts/Rln.sol";
import "./Verifier.sol";
import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";

contract RlnTest is Test {
    using stdStorage for StdStorage;

    Rln public rln;
    PoseidonHasher public poseidon;
    TrueVerifier public trueVerifier;
    FalseVerifier public falseVerifier;

    uint256 public constant MEMBERSHIP_DEPOSIT = 1000000000000000;
    uint256 public constant DEPTH = 20;
    uint256 public constant SET_SIZE = 1048576;
    uint256[8] public zeroedProof = [0, 0, 0, 0, 0, 0, 0, 0];

    /// @dev Setup the testing environment.
    function setUp() public {
        poseidon = new PoseidonHasher();
        trueVerifier = new TrueVerifier();
        falseVerifier = new FalseVerifier();
        rln = new Rln(MEMBERSHIP_DEPOSIT, DEPTH, address(poseidon), address(trueVerifier));
    }

    /// @dev Ensure that you can hash a value.
    function test__Constants() public {
        assertEq(rln.MEMBERSHIP_DEPOSIT(), MEMBERSHIP_DEPOSIT);
        assertEq(rln.DEPTH(), DEPTH);
        assertEq(rln.SET_SIZE(), SET_SIZE);
        assertEq(rln.deployedBlockNumber(), 1);
    }

    function test__ValidRegistration(uint256 idCommitment) public {
        vm.assume(rln.isValidCommitment(idCommitment));
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        // assertEq(rln.memberExists(idCommitment), true);
        // assertEq(rln.members(idCommitment), 0);
    }

    function test__InvalidRegistration__DuplicateCommitment(uint256 idCommitment) public {
        vm.assume(rln.isValidCommitment(idCommitment));
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        assertEq(rln.memberExists(idCommitment), true);
        assertEq(rln.members(idCommitment), 0);
        vm.expectRevert(DuplicateIdCommitment.selector);
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
    }

    function test__InvalidRegistration__InvalidIdCommitment(uint256 idCommitment) public {
        vm.assume(!rln.isValidCommitment(idCommitment));
        vm.expectRevert(abi.encodeWithSelector(InvalidIdCommitment.selector, idCommitment));
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
    }

    function test__InvalidRegistration__InsufficientDeposit(uint256 idCommitment) public {
        vm.assume(rln.isValidCommitment(idCommitment));
        uint256 badDepositAmount = MEMBERSHIP_DEPOSIT - 1;
        vm.expectRevert(abi.encodeWithSelector(InsufficientDeposit.selector, MEMBERSHIP_DEPOSIT, badDepositAmount));
        rln.register{value: badDepositAmount}(idCommitment);
    }

    function test__InvalidRegistration__FullSet() public {
        Rln tempRln = new Rln(
            MEMBERSHIP_DEPOSIT,
            2,
            address(rln.poseidonHasher()),
            address(rln.verifier())
        );
        uint256 setSize = tempRln.SET_SIZE();
        for (uint256 i = 1; i <= setSize; i++) {
            tempRln.register{value: MEMBERSHIP_DEPOSIT}(i);
        }
        assertEq(tempRln.idCommitmentIndex(), 4);
        vm.expectRevert(FullTree.selector);
        tempRln.register{value: MEMBERSHIP_DEPOSIT}(setSize + 1);
    }

    function test__ValidSlash(uint256 idCommitment, address payable to) public {
        // avoid precompiles, etc
        // TODO: wrap both of these in a single function
        assumePayable(to);
        assumeNotPrecompile(to);
        vm.assume(to != address(0));
        vm.assume(rln.isValidCommitment(idCommitment));

        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
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
        uint256 idCommitment = 9014214495641488759237505126948346942972912379615652741039992445865937985820;

        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
        assertEq(rln.stakedAmounts(idCommitment), MEMBERSHIP_DEPOSIT);
        vm.expectRevert(abi.encodeWithSelector(InvalidReceiverAddress.selector, address(0)));
        rln.slash(idCommitment, payable(address(0)), zeroedProof);
    }

    function test__InvalidSlash__ToRlnAddress() public {
        uint256 idCommitment = 19014214495641488759237505126948346942972912379615652741039992445865937985820;
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
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

        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
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
        uint256 idCommitment = 19014214495641488759237505126948346942972912379615652741039992445865937985820;

        Rln tempRln = new Rln(
            MEMBERSHIP_DEPOSIT,
            2,
            address(rln.poseidonHasher()),
            address(falseVerifier)
        );

        tempRln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);

        vm.expectRevert(InvalidProof.selector);
        tempRln.slash(idCommitment, payable(address(this)), zeroedProof);
    }

    function test__InvalidWithdraw__InsufficientWithdrawalBalance() public {
        vm.expectRevert(InsufficientWithdrawalBalance.selector);
        rln.withdraw();
    }

    function test__InvalidWithdraw__InsufficientContractBalance() public {
        uint256 idCommitment = 19014214495641488759237505126948346942972912379615652741039992445865937985820;
        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
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

        uint256 idCommitment = 19014214495641488759237505126948346942972912379615652741039992445865937985820;

        rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitment);
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
        uint256[] memory idCommitments = new uint256[](10);
        idCommitments[0] = 19143711682366759980911001457853255795836264632723844153354310748778748156460;
        idCommitments[1] = 16984765328852711772291441487727981184905800779020079168989152080434188364678;
        idCommitments[2] = 10972315136095845343447418815139813428649316683283020632475608655814722712541;
        idCommitments[3] = 2709631781045191277266130708832884002577134582503944059038971337978087532997;
        idCommitments[4] = 8255654132980945447086418574686169461187805238257784695584517016324877809505;
        idCommitments[5] = 20291701150251695209910387548168084091751201746043024067531503187703236470983;
        idCommitments[6] = 11817872986033932471261438074921403500882957864164537515599299873089437746577;
        idCommitments[7] = 18475838919635792169148272767721284591038756730004222133003018558598315558783;
        idCommitments[8] = 10612118277928165031660389522171737855229037400929675201853245490188277695983;
        idCommitments[9] = 17318633845296358766427229711888486415250435256643711009388405482885762601797;

        vm.pauseGasMetering();
        for (uint256 i = 0; i < idCommitments.length; i++) {
            rln.register{value: MEMBERSHIP_DEPOSIT}(idCommitments[i]);
        }
        vm.resumeGasMetering();

        assertEq(rln.root(), 5210724218081541877101688952118136930297124697603087561558225712176057209122);
    }
}
