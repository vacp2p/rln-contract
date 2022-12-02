import { ethers } from "ethers";
import createProof from "@interep/proof";
import createIdentity from "@interep/identity";
import dotenv from "dotenv";

import { abi, address } from "../deployments/goerli/RLN.json";
import { sToBytes32 } from "../common";

dotenv.config();

// This function does the following -
// 1. Creates an identity using createIdentity
// 2. Creates a proof using createProof
// 3. Calls the register function on the RLN contract, with the proof that was generated
// !!!NOTE!!!
// Interep has not updated their verifiers, so the proof generated by createProof will not work :( Have raised the issue with their team
async function main() {
  if (!process.env.PRIVATE_KEY_TO_GENERATE_SECRET) {
    throw new Error("PRIVATE_KEY_TO_GENERATE_SECRET not set");
  }
  if (!process.env.PRIVATE_KEY) {
    throw new Error("PRIVATE_KEY not set");
  }
  const provider = new ethers.providers.JsonRpcProvider(process.env.GOERLI_URL);
  const wallet = new ethers.Wallet(
    process.env.PRIVATE_KEY_TO_GENERATE_SECRET,
    provider
  );

  const identity = await createIdentity(
    (msg) => wallet.signMessage(msg),
    "Github"
  );

  const proof = await createProof(
    identity,
    "github",
    "bronze",
    1,
    sToBytes32("foo"),
    {
      wasmFilePath: "./test/snarkArtifacts/semaphore.wasm",
      zkeyFilePath: "./test/snarkArtifacts/semaphore.zkey",
    },
    "goerli"
  );

  console.log(address);
  const rlnContract = new ethers.Contract(
    address,
    abi,
    new ethers.Wallet(process.env.PRIVATE_KEY, provider)
  );
  console.log(
    proof.groupId,
    proof.signal,
    proof.publicSignals.nullifierHash,
    proof.publicSignals.externalNullifier,
    proof.solidityProof,
    identity.getCommitment(),
    proof.publicSignals.signalHash
  );
  const tx = await rlnContract[
    "register(uint256,bytes32,uint256,uint256,uint256[8],uint256)"
  ](
    proof.groupId,
    proof.signal,
    proof.publicSignals.nullifierHash,
    proof.publicSignals.externalNullifier,
    proof.solidityProof,
    identity.getCommitment()
  );

  console.log(tx.hash);
  await tx.wait();

  console.log("done");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });