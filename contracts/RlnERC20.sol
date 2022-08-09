pragma solidity 0.7.4;

import { IPoseidonHasher } from "./PoseidonHasher.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RLNERC20 {
	uint256 public immutable MEMBERSHIP_DEPOSIT;
	uint256 public immutable DEPTH;
	uint256 public immutable SET_SIZE;

	uint256 public pubkeyIndex = 0;
	mapping(uint256 => uint256) public members;

	IPoseidonHasher public poseidonHasher;

	event MemberRegistered(uint256 pubkey, uint256 index);
	event MemberWithdrawn(uint256 pubkey, uint256 index);

	IERC20 immutable AcceptedToken;

	constructor(
		uint256 membershipDeposit,
		uint256 depth,
		address _poseidonHasher,
		address _acceptedTokenAddress
	) public {
		MEMBERSHIP_DEPOSIT = membershipDeposit;
		DEPTH = depth;
		SET_SIZE = 1 << depth;
		poseidonHasher = IPoseidonHasher(_poseidonHasher);
		AcceptedToken = IERC20(_acceptedTokenAddress);
	}

	function registerWithAcceptedToken(uint256 deposit, uint256 pubkey) external payable {
		require(pubkeyIndex < SET_SIZE, "RLN, register: set is full");
		require(deposit == MEMBERSHIP_DEPOSIT, "RLN, register: membership deposit is not satisfied");
		AcceptedToken.transferFrom(msg.sender,address(this),deposit);
		_register(pubkey);
	}

	function registerBatchWithAcceptedToken(uint256 deposit, uint256[] calldata pubkeys) external payable {
		require(pubkeyIndex + pubkeys.length <= SET_SIZE, "RLN, registerBatch: set is full");
		require(deposit == MEMBERSHIP_DEPOSIT * pubkeys.length, "RLN, registerBatch: membership deposit is not satisfied");
		AcceptedToken.transferFrom(msg.sender,address(this),deposit);
		for (uint256 i = 0; i < pubkeys.length; i++) {
			_register(pubkeys[i]);
		}
	}

	function _register(uint256 pubkey) internal {
		members[pubkeyIndex] = pubkey;
		emit MemberRegistered(pubkey, pubkeyIndex);
		pubkeyIndex += 1;
	}

	function withdrawBatch(
		uint256[] calldata secrets,
		uint256[] calldata pubkeyIndexes
	) external {
		uint256 batchSize = secrets.length;
		require(batchSize != 0, "RLN, withdrawBatch: batch size zero");
		require(batchSize == pubkeyIndexes.length, "RLN, withdrawBatch: batch size mismatch pubkey indexes");
		for (uint256 i = 0; i < batchSize; i++) {
			_withdraw(secrets[i], pubkeyIndexes[i], msg.sender);
		}
	}

	function withdraw(
		uint256 secret,
		uint256 _pubkeyIndex
	) external {
		_withdraw(secret, _pubkeyIndex, msg.sender);
	}

	function _withdraw(
		uint256 secret,
		uint256 _pubkeyIndex,
		address payable receiver
	) internal {
		require(_pubkeyIndex < SET_SIZE, "RLN, _withdraw: invalid pubkey index");
		require(members[_pubkeyIndex] != 0, "RLN, _withdraw: member doesn't exist");
		require(receiver != address(0), "RLN, _withdraw: empty receiver address");

		// derive public key
		uint256 pubkey = hash([secret, 0]);
		require(members[_pubkeyIndex] == pubkey, "RLN, _withdraw: not verified");

		// delete member
		members[_pubkeyIndex] = 0;

		// refund deposit
		AcceptedToken.transferFrom(address(this),receiver,MEMBERSHIP_DEPOSIT);

		emit MemberWithdrawn(pubkey, _pubkeyIndex);
	}

	function hash(uint256[2] memory input) internal view returns (uint256) {
		return poseidonHasher.hash(input);
	}
}