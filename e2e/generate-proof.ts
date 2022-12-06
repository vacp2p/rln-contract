import createIdentity from "@interep/identity";
import { ethers } from "ethers";
import { createInterepProof, sToBytes32 } from "../common";
// @ts-ignore circom
import { poseidon } from "circomlibjs";

const privateKey = process.argv[2];
const rawExistingMembers = process.argv[3] || "[]";

const existingMembers = JSON.parse(rawExistingMembers);

if (!privateKey) {
  console.log("Usage: node generate-proof.js <privateKey>");
  process.exit(1);
}

async function main() {
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
  const identitySecretHash = poseidon([
    identity.getNullifier(),
    identity.getTrapdoor(),
  ]);
  const returnObj = {};
  Object.assign(returnObj, {
    identitySecretHash: identitySecretHash.toString(16),
    identityCommitment: identity.getCommitment().toString(16),
    groupId: proof.groupId,
    signal: proof.signal,
    nullifierHash: proof.publicSignals.nullifierHash,
    externalNullifier: proof.publicSignals.externalNullifier,
    solidityProof: proof.solidityProof,
  });
  console.log(returnObj);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
