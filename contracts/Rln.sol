pragma solidity 0.8.15;

import { IPoseidonHasher } from "./PoseidonHasher.sol";

contract RLN {
	uint256 public immutable MEMBERSHIP_DEPOSIT;
	uint256 public immutable DEPTH;
	uint256 public immutable SET_SIZE;

	uint256 public pubkeyIndex = 0;
	// This mapping is used to keep track of the public keys that have been registered
	// with the stake
	mapping(uint256 => uint256) public members;

	IPoseidonHasher public poseidonHasher;

	event MemberRegistered(uint256 pubkey, uint256 index);
	event MemberWithdrawn(uint256 pubkey);

	constructor(
		uint256 membershipDeposit,
		uint256 depth,
		address _poseidonHasher
	) {
		MEMBERSHIP_DEPOSIT = membershipDeposit;
		DEPTH = depth;
		SET_SIZE = 1 << depth;
		poseidonHasher = IPoseidonHasher(_poseidonHasher);
	}

	function register(uint256 pubkey) external payable {
		require(members[pubkey] == 0, "RLN, register: pubkey already registered");
		require(pubkeyIndex < SET_SIZE, "RLN, register: set is full");
		require(msg.value == MEMBERSHIP_DEPOSIT, "RLN, register: membership deposit is not satisfied");
		_register(pubkey);
	}

	function registerBatch(uint256[] calldata pubkeys) external payable {
		uint256 pubkeylen = pubkeys.length;
		require(pubkeyIndex + pubkeylen <= SET_SIZE, "RLN, registerBatch: set is full");
		require(msg.value == MEMBERSHIP_DEPOSIT * pubkeylen, "RLN, registerBatch: membership deposit is not satisfied");
		for (uint256 i = 0; i < pubkeylen; i++) {
			_register(pubkeys[i]);
		}
	}

	function _register(uint256 pubkey) internal {
		// Set the pubkey to the value of the tx
		members[pubkey] = msg.value;
		emit MemberRegistered(pubkey, pubkeyIndex);
		pubkeyIndex += 1;
	}

	function withdrawBatch(
		uint256[] calldata secrets,
		address payable[] calldata receivers
	) external {
		uint256 batchSize = secrets.length;
		require(batchSize != 0, "RLN, withdrawBatch: batch size zero");
		require(batchSize == receivers.length, "RLN, withdrawBatch: batch size mismatch receivers");
		for (uint256 i = 0; i < batchSize; i++) {
			_withdraw(secrets[i], receivers[i]);
		}
	}

	function withdraw(
		uint256 secret,
		address payable receiver
	) external {
		_withdraw(secret, receiver);
	}

	function _withdraw(
		uint256 secret,
		address payable receiver
	) internal {
		// derive public key
		uint256 pubkey = hash(secret);
		require(members[pubkey] != 0, "RLN, _withdraw: member doesn't exist");
		require(receiver != address(0), "RLN, _withdraw: empty receiver address");
	
		// refund deposit
		(bool sent, bytes memory data) = receiver.call{value: members[pubkey]}("");
        require(sent, "transfer failed");

		// delete member only if refund is successful
		members[pubkey] = 0;

		emit MemberWithdrawn(pubkey);
	}

	function hash(uint256 input) internal view returns (uint256) {
		return poseidonHasher.hash(input);
	}
}