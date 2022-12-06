import createIdentity from "@interep/identity";
import { ethers } from "ethers";
import { createInterepProof, sToBytes32 } from "../common";
// @ts-ignore circom
import { poseidon } from "circomlibjs";
import fs from "fs";

import { address, abi } from "../deployments/localhost_integration/RLN.json";

import { seedTree } from "./seed-tree";
import { updateMerkleRoot } from "./update-merkle-root";

const privateKey = process.argv[2];
const rawExistingMembers = process.argv[3] || "[]";

const existingMembers = JSON.parse(rawExistingMembers);

if (!privateKey) {
  console.log("Usage: yarn ts-node e2e/e2e <privateKey>");
  process.exit(1);
}

async function main() {
  const provider = new ethers.providers.JsonRpcProvider(
    "http://localhost:8545"
  );
  const signer = provider.getSigner(0);
  const rlnContract = new ethers.Contract(address, abi, signer);

  // Seed test tree
  await seedTree(rlnContract);

  const wallet = new ethers.Wallet(privateKey);
  const identity = await createIdentity(
    (msg) => wallet.signMessage(msg),
    "Github"
  );
  const proof = await createInterepProof({
    identity,
    members: [...existingMembers, identity.getCommitment()],
    groupProvider: "github",
    groupTier: "bronze",
    signal: sToBytes32("foo"),
    externalNullifier: 1,
    snarkArtifacts: {
      wasmFilePath: "./test/snarkArtifacts/semaphore.wasm",
      zkeyFilePath: "./test/snarkArtifacts/semaphore.zkey",
    },
  });
  console.log("Proof generated for registration");

  const identitySecretHash = poseidon([
    identity.getNullifier(),
    identity.getTrapdoor(),
  ]).toString(16);
  const identityCommitment = identity.getCommitment().toString(16);

  // Update on-chain merkle root to include new member
  await updateMerkleRoot(
    signer,
    "github",
    "bronze",
    proof.publicSignals.merkleRoot
  );

  // Register new member
  const registerTx = await rlnContract[
    "register(uint256,bytes32,uint256,uint256,uint256[8],uint256)"
  ](
    proof.groupId,
    proof.signal,
    proof.publicSignals.nullifierHash,
    proof.publicSignals.externalNullifier,
    proof.solidityProof,
    identity.getCommitment()
  );
  const txData = await registerTx.wait();
  const rlnIndex = txData.events[1].args.index.toNumber();

  console.log(
    `New member registered: \nID COMMITMENT: ${identityCommitment}\nID KEY: ${identitySecretHash}\nRLN INDEX: ${rlnIndex}`
  );
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
