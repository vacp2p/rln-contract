import { expect } from "chai";
import { ethers, deployments } from "hardhat";

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

    const pubkey = txRegisterReceipt.events[0].args.idCommitment;

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
    await registerTx.wait();

    // We withdraw our id_commitment
    const receiverAddress = "0x000000000000000000000000000000000000dead";
    const withdrawTx = await rln["withdraw(uint256,address)"](
      idSecret,
      receiverAddress
    );

    const txWithdrawReceipt = await withdrawTx.wait();

    const withdrawalPk = txWithdrawReceipt.events[0].args.idCommitment;

    // We ensure the registered id_commitment is the one we passed and that the index is the same
    expect(
      withdrawalPk.toHexString() === idCommitment,
      "withdraw commitment doesn't match registered commitment"
    );
  });

  it("should not allow multiple registrations with same pubkey", async () => {
    const rln = await ethers.getContract("RLN", ethers.provider.getSigner(0));

    const price = await rln.MEMBERSHIP_DEPOSIT();

    // A valid pair of (id_secret, id_commitment) generated in rust
    const idCommitment =
      "0x0c3ac305f6a4fe9bfeb3eba978bc876e2a99208b8b56c80160cfb54ba8f02368";

    const registerTx = await rln["register(uint256)"](idCommitment, {
      value: price,
    });
    await registerTx.wait();

    // Send the same tx again
    const registerTx2 = rln["register(uint256)"](idCommitment, {
      value: price,
    });

    await expect(registerTx2).to.be.revertedWith(
      "RLN, _register: member already registered"
    );
  });
});
