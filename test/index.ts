import { assert } from "chai";
import { ethers } from "hardhat";

describe.skip("Rln", function () {
  it("Deploying", async function () {
    const PoseidonHasher = await ethers.getContractFactory("PoseidonHasher");
    const poseidonHasher = await PoseidonHasher.deploy();
  
    await poseidonHasher.deployed();
  
    console.log("PoseidonHasher deployed to:", poseidonHasher.address);

    const Rln = await ethers.getContractFactory("RLN");
    const rln = await Rln.deploy(1000000000000000, 20, poseidonHasher.address);
  
    await rln.deployed();

    console.log("Rln deployed to:", rln.address);
    
    const price = await rln.MEMBERSHIP_DEPOSIT();

    // A valid pair of (id_secret, id_commitment) generated in rust
    const id_secret = "0x2a09a9fd93c590c26b91effbb2499f07e8f7aa12e2b4940a3aed2411cb65e11c"
    const id_commitment = "0x0c3ac305f6a4fe9bfeb3eba978bc876e2a99208b8b56c80160cfb54ba8f02368"

    const res_register = await rln.register(id_commitment, {value: price});
    const txRegisterReceipt = await res_register.wait();

    const reg_pubkey =  txRegisterReceipt.events[0].args.pubkey;
    const reg_tree_index =  txRegisterReceipt.events[0].args.index;

    // We ensure the registered id_commitment is the one we passed
    assert(reg_pubkey.toHexString() === id_commitment, "registered commitment doesn't match passed commitment");

    // We withdraw our id_commitment
    const receiver_address = "0x000000000000000000000000000000000000dead";
    const res_withdraw = await rln.withdraw(id_secret, reg_tree_index, receiver_address);
    
    const txWithdrawReceipt = await res_withdraw.wait();

    const wit_pubkey =  txWithdrawReceipt.events[0].args.pubkey;
    const wit_tree_index =  txWithdrawReceipt.events[0].args.index;

    // We ensure the registered id_commitment is the one we passed and that the index is the same
    assert(wit_pubkey.toHexString() === id_commitment, "withdraw commitment doesn't match registered commitmet");
    assert(wit_tree_index.toHexString() === reg_tree_index.toHexString(), "withdraw index doesn't match registered index");

  });
});