import { expect } from "chai";
import { ethers, deployments } from "hardhat";

describe("WakuRlnRegistry", () => {
  beforeEach(async () => {
    await deployments.fixture(["WakuRlnStorage"]);
  });

  it("should register new memberships", async () => {
    const registryDeployment = await deployments.get("WakuRlnRegistry_Proxy");
    const implDeployment = await deployments.get(
      "WakuRlnRegistry_Implementation"
    );
    const rlnRegistry = new ethers.Contract(
      registryDeployment.address,
      implDeployment.abi,
      ethers.provider.getSigner(0)
    );
    const rlnStorage = await ethers.getContract(
      "WakuRlnStorage_0",
      ethers.provider.getSigner(0)
    );

    // A valid pair of (id_secret, id_commitment) generated in rust
    const idCommitment =
      "0x0c3ac305f6a4fe9bfeb3eba978bc876e2a99208b8b56c80160cfb54ba8f02368";

    const registerTx = await rlnRegistry["register(uint16,uint256)"](
      await rlnRegistry.usingStorageIndex(),
      idCommitment
    );
    const txRegisterReceipt = await registerTx.wait();

    // parse the event into (uint256, uint256)
    const event = rlnStorage.interface.parseLog(txRegisterReceipt.events[0]);
    const fetchedIdCommitment = event.args.idCommitment;

    // We ensure the registered id_commitment is the one we passed
    expect(
      fetchedIdCommitment.toHexString() === idCommitment,
      "registered commitment doesn't match passed commitment"
    );
  });
});
