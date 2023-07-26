import { expect } from "chai";
import { ethers, deployments } from "hardhat";

describe("Rln", () => {
  beforeEach(async () => {
    await deployments.fixture(["Rln"]);
  });

  it("should register new memberships", async () => {
    const rln = await ethers.getContract("Rln", ethers.provider.getSigner(0));

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

  it("should slash membership", async () => {
    const rln = await ethers.getContract("Rln", ethers.provider.getSigner(0));

    const price = await rln.MEMBERSHIP_DEPOSIT();

    // A valid id_commitment generated in zerokit
    const idCommitment =
      "0x0c3ac305f6a4fe9bfeb3eba978bc876e2a99208b8b56c80160cfb54ba8f02368";

    const registerTx = await rln["register(uint256)"](idCommitment, {
      value: price,
    });
    await registerTx.wait();

    // We slash the id_commitment
    const receiverAddress = "0x000000000000000000000000000000000000dead";
    const slashTx = rln["slash(uint256,address,uint256[8])"](
      idCommitment,
      receiverAddress,
      [0, 0, 0, 0, 0, 0, 0, 0]
    );

    await expect(slashTx).to.be.revertedWith("InvalidProof()");
  });

  it("should not allow multiple registrations with same pubkey", async () => {
    const rln = await ethers.getContract("Rln", ethers.provider.getSigner(0));

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

    await expect(registerTx2).to.be.revertedWith("DuplicateIdCommitment()");
  });
});
