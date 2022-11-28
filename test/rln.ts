import { expect, assert } from "chai";
import { BigNumber } from "ethers";
import { ethers, deployments } from "hardhat";
import { createGroupId } from "../common";

describe("RLN", () => {
  beforeEach(async () => {
    await deployments.fixture(["RLN"]);
  });

  it("should register new memberships", async () => {
    const rln = await ethers.getContract("RLN", ethers.provider.getSigner(0));

    const price = await rln.MEMBERSHIP_DEPOSIT();

    // A valid pair of (id_secret, id_commitment) generated in rust
    const idCommitment =
      "0x0c3ac305f6a4fe9bfeb3eba978bc876e2a99208b8b56c80160cfb54ba8f02368";

    const registerTx = await rln["register(uint256)"](idCommitment, {
      value: price,
    });
    const txRegisterReceipt = await registerTx.wait();

    const pubkey = txRegisterReceipt.events[0].args.pubkey;

    // We ensure the registered id_commitment is the one we passed
    expect(
      pubkey.toHexString() === idCommitment,
      "registered commitment doesn't match passed commitment"
    );
  });

  it("should withdraw membership", async () => {
    const rln = await ethers.getContract("RLN", ethers.provider.getSigner(0));

    const price = await rln.MEMBERSHIP_DEPOSIT();

    // A valid pair of (id_secret, id_commitment) generated in rust
    const idSecret =
      "0x2a09a9fd93c590c26b91effbb2499f07e8f7aa12e2b4940a3aed2411cb65e11c";
    const idCommitment =
      "0x0c3ac305f6a4fe9bfeb3eba978bc876e2a99208b8b56c80160cfb54ba8f02368";

    const registerTx = await rln["register(uint256)"](idCommitment, {
      value: price,
    });
    const txRegisterReceipt = await registerTx.wait();

    const treeIndex = txRegisterReceipt.events[0].args.index;

    // We withdraw our id_commitment
    const receiverAddress = "0x000000000000000000000000000000000000dead";
    const withdrawTx = await rln.withdraw(idSecret, treeIndex, receiverAddress);

    const txWithdrawReceipt = await withdrawTx.wait();

    const withdrawalPk = txWithdrawReceipt.events[0].args.pubkey;
    const withdrawalTreeIndex = txWithdrawReceipt.events[0].args.index;

    // We ensure the registered id_commitment is the one we passed and that the index is the same
    expect(
      withdrawalPk.toHexString() === idCommitment,
      "withdraw commitment doesn't match registered commitment"
    );
    expect(
      withdrawalTreeIndex.toHexString() === treeIndex.toHexString(),
      "withdraw index doesn't match registered index"
    );
  });

  it.skip("should not allow multiple registrations with same pubkey", async () => {
    const rln = await ethers.getContract("RLN", ethers.provider.getSigner(0));

    const price = await rln.MEMBERSHIP_DEPOSIT();

    // A valid pair of (id_secret, id_commitment) generated in rust
    const idCommitment =
      "0x0c3ac305f6a4fe9bfeb3eba978bc876e2a99208b8b56c80160cfb54ba8f02368";

    const registerTx = await rln["register(uint256)"](idCommitment, {
      value: price,
    });
    const txRegisterReceipt = await registerTx.wait();
    const index1 = txRegisterReceipt.events[0].args.index;

    // Send the same tx again
    const registerTx2 = await rln["register(uint256)"](idCommitment, {
      value: price,
    });
    const txRegisterReceipt2 = await registerTx2.wait();
    const index2 = txRegisterReceipt2.events[0].args.index;

    const pk1 = await rln.members(index1);
    const pk2 = await rln.members(index2);
    const samePk = pk1.toHexString() === pk2.toHexString();
    if (samePk) {
      assert(false, "same pubkey registered twice");
    }
  });

  it("[interep] should register new memberships", async () => {
    const rln = await ethers.getContract("RLN", ethers.provider.getSigner(0));

    const validGroupId = createGroupId("github", "silver");
    const dummySignal = ethers.utils.formatBytes32String("foo");
    const dummyNullifierHash = BigNumber.from(0);
    const dummyExternalNullifier = BigNumber.from(0);
    const dummyProof = Array(8).fill(BigNumber.from(0));
    const dummyPubkey = BigNumber.from(0);

    const registerTx = await rln[
      "register(uint256,bytes32,uint256,uint256,uint256[8],uint256)"
    ](
      validGroupId,
      dummySignal,
      dummyNullifierHash,
      dummyExternalNullifier,
      dummyProof,
      dummyPubkey
    );
    const txRegisterReceipt = await registerTx.wait();

    const iface = new ethers.utils.Interface([
      "event ProofVerified(uint256 indexed groupId, bytes32 signal)",
    ]);
    const event = iface.parseLog(txRegisterReceipt.events[0]);
    expect(event.args.groupId.toHexString()).to.equal(
      BigNumber.from(validGroupId).toHexString()
    );
    expect(event.args.signal).to.equal(dummySignal);

    const pubkey = txRegisterReceipt.events[1].args.pubkey;
    expect(pubkey.toHexString() === dummyPubkey.toHexString());
  });

  it("[interep] should withdraw membership", () => {
    // TODO
  });
});
