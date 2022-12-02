import { expect, assert } from "chai";
import { BigNumber } from "ethers";
import { ethers, deployments } from "hardhat";
import {
  createGroupId,
  createInterepIdentity,
  createInterepProof,
  getGroups,
  getValidGroups,
  merkleTreeDepth,
  sToBytes32,
} from "../common";

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

  it("should not withdraw stake without address", async () => {
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
    const withdrawTx = rln["withdraw(uint256)"](idSecret);

    await expect(withdrawTx).to.be.revertedWith("RLN, _withdraw: staked");
  });

  it("should not withdraw withdraw stake if no stake exists", async () => {
    const rln = await ethers.getContract("RLN", ethers.provider.getSigner(0));

    const validGroupId = createGroupId("github", "bronze");
    const dummySignal = sToBytes32("foo");
    const dummyNullifierHash = BigNumber.from(0);
    const dummyExternalNullifier = BigNumber.from(0);
    const dummyProof = Array(8).fill(BigNumber.from(0));

    const idCommitment = BigNumber.from(
      "0x0c3ac305f6a4fe9bfeb3eba978bc876e2a99208b8b56c80160cfb54ba8f02368"
    );
    const secret =
      "0x2a09a9fd93c590c26b91effbb2499f07e8f7aa12e2b4940a3aed2411cb65e11c";

    const registerTx = await rln[
      "register(uint256,bytes32,uint256,uint256,uint256[8],uint256)"
    ](
      validGroupId,
      dummySignal,
      dummyNullifierHash,
      dummyExternalNullifier,
      dummyProof,
      idCommitment
    );

    await registerTx.wait();

    const address = "0x000000000000000000000000000000000000dead";
    const withdrawTx = rln["withdraw(uint256,address)"](secret, address);

    await expect(withdrawTx).to.be.revertedWith(
      "RLN, _withdraw: member has no stake"
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

  it("[interep] should register new memberships", async () => {
    const rln = await ethers.getContract("RLN", ethers.provider.getSigner(0));

    const validGroupId = createGroupId("github", "bronze");
    const dummySignal = sToBytes32("foo");
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

    const pubkey = txRegisterReceipt.events[1].args.idCommitment;
    expect(pubkey.toHexString() === dummyPubkey.toHexString());
  });

  it("[interep] should generate proof for registration", async () => {
    const signer = ethers.provider.getSigner(0);
    const identity = await createInterepIdentity(signer, "github");

    // create a proof to test
    const proof = await createInterepProof({
      identity,
      members: [identity.getCommitment()],
      groupProvider: "github",
      groupTier: "silver",
      signal: "foo",
      externalNullifier: 1,
      snarkArtifacts: {
        wasmFilePath: "./test/snarkArtifacts/semaphore.wasm",
        zkeyFilePath: "./test/snarkArtifacts/semaphore.zkey",
      },
    });

    expect(proof.groupId).to.eql(
      "19580063316323634959827976785370507245708993886389832860880129572471638471998"
    );
    expect(proof.publicSignals.merkleRoot).to.eql(
      "10738127364751233254031334835017982823925916365031589705155005906674724477907"
    );
  });

  it("[interep] should register with valid proof", async () => {
    // need to create new fixtures for this test
    const { PoseidonHasher } = await deployments.fixture("PoseidonHasher");
    const verifier20Factory = await ethers.getContractFactory("Verifier20");
    const verifier20 = await verifier20Factory.deploy();
    await verifier20.deployed();
    const interepFactory = await ethers.getContractFactory(
      "Interep",
      ethers.provider.getSigner(0)
    );
    const interep = await interepFactory.deploy([
      {
        contractAddress: verifier20.address,
        merkleTreeDepth: merkleTreeDepth,
      },
    ]);
    await interep.deployed();
    const groupTx = await interep.updateGroups(getGroups());
    await groupTx.wait();

    const validGroupStorageFactory = await ethers.getContractFactory(
      "ValidGroupStorage"
    );
    const validGroupStorage = await validGroupStorageFactory.deploy(
      interep.address,
      getValidGroups()
    );
    await validGroupStorage.deployed();

    const rlnFactory = await ethers.getContractFactory(
      "RLN",
      ethers.provider.getSigner(0)
    );
    const rln = await rlnFactory.deploy(
      1000000000000000,
      20,
      PoseidonHasher.address,
      validGroupStorage.address
    );

    await rln.deployed();

    const identity = await createInterepIdentity(
      ethers.provider.getSigner(0),
      "github"
    );

    // create a proof to test
    const proof = await createInterepProof({
      identity,
      members: [identity.getCommitment()],
      groupProvider: "github",
      groupTier: "bronze",
      signal: sToBytes32("foo"),
      externalNullifier: 1,
      snarkArtifacts: {
        wasmFilePath: "./test/snarkArtifacts/semaphore.wasm",
        zkeyFilePath: "./test/snarkArtifacts/semaphore.zkey",
      },
    });

    // update root of group
    const groupUpdateTx = await interep.updateGroups([
      {
        provider: sToBytes32("github"),
        name: sToBytes32("bronze"),
        root: proof.publicSignals.merkleRoot,
        depth: 20,
      },
    ]);

    await groupUpdateTx.wait();

    const registerTx = await rln[
      "register(uint256,bytes32,uint256,uint256,uint256[8],uint256)"
    ](
      proof.groupId,
      proof.signal,
      proof.publicSignals.nullifierHash,
      proof.publicSignals.externalNullifier,
      proof.solidityProof,
      identity.getCommitment()
    );

    const txRegisterReceipt = await registerTx.wait();

    expect(txRegisterReceipt.events[1].args.idCommitment.toHexString()).to.eql(
      BigNumber.from(identity.getCommitment()).toHexString()
    );
  });

  it("[interep] should revert with invalid proof", async () => {
    // need to create new fixtures for this test
    const { PoseidonHasher } = await deployments.fixture("PoseidonHasher");
    const verifier20Factory = await ethers.getContractFactory("Verifier20");
    const verifier20 = await verifier20Factory.deploy();
    await verifier20.deployed();
    const interepFactory = await ethers.getContractFactory(
      "Interep",
      ethers.provider.getSigner(0)
    );
    const interep = await interepFactory.deploy([
      {
        contractAddress: verifier20.address,
        merkleTreeDepth: merkleTreeDepth,
      },
    ]);
    await interep.deployed();
    const groupTx = await interep.updateGroups(getGroups());
    await groupTx.wait();

    const validGroupStorageFactory = await ethers.getContractFactory(
      "ValidGroupStorage"
    );
    const validGroupStorage = await validGroupStorageFactory.deploy(
      interep.address,
      getValidGroups()
    );
    await validGroupStorage.deployed();

    const rlnFactory = await ethers.getContractFactory(
      "RLN",
      ethers.provider.getSigner(0)
    );
    const rln = await rlnFactory.deploy(
      1000000000000000,
      20,
      PoseidonHasher.address,
      validGroupStorage.address
    );

    await rln.deployed();

    const identity = await createInterepIdentity(
      ethers.provider.getSigner(0),
      "github"
    );

    // create a proof to test
    const proof = await createInterepProof({
      identity,
      members: [identity.getCommitment()],
      groupProvider: "github",
      groupTier: "bronze",
      signal: sToBytes32("foo"),
      externalNullifier: 1,
      snarkArtifacts: {
        wasmFilePath: "./test/snarkArtifacts/semaphore.wasm",
        zkeyFilePath: "./test/snarkArtifacts/semaphore.zkey",
      },
    });

    // do not update root of group

    const registerTx = rln[
      "register(uint256,bytes32,uint256,uint256,uint256[8],uint256)"
    ](
      proof.groupId,
      proof.signal,
      proof.publicSignals.nullifierHash,
      proof.publicSignals.externalNullifier,
      proof.solidityProof,
      identity.getCommitment()
    );

    await expect(registerTx).to.be.revertedWith("InvalidProof()");
  });

  it("[interep] should withdraw a registration", async () => {
    const rln = await ethers.getContract("RLN", ethers.provider.getSigner(0));

    const validGroupId = createGroupId("github", "bronze");
    const dummySignal = sToBytes32("foo");
    const dummyNullifierHash = BigNumber.from(0);
    const dummyExternalNullifier = BigNumber.from(0);
    const dummyProof = Array(8).fill(BigNumber.from(0));

    const idCommitment = BigNumber.from(
      "0x0c3ac305f6a4fe9bfeb3eba978bc876e2a99208b8b56c80160cfb54ba8f02368"
    );
    const secret =
      "0x2a09a9fd93c590c26b91effbb2499f07e8f7aa12e2b4940a3aed2411cb65e11c";

    const registerTx = await rln[
      "register(uint256,bytes32,uint256,uint256,uint256[8],uint256)"
    ](
      validGroupId,
      dummySignal,
      dummyNullifierHash,
      dummyExternalNullifier,
      dummyProof,
      idCommitment
    );

    await registerTx.wait();

    const withdrawTx = await rln["withdraw(uint256)"](secret);

    const txWithdrawReceipt = await withdrawTx.wait();

    expect(txWithdrawReceipt.events[0].args.idCommitment).to.eql(idCommitment);
  });
});
