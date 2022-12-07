import createIdentity from "@interep/identity";
import createProof from "@interep/proof";
import { ethers } from "ethers";
// @ts-ignore
import { poseidon } from "circomlibjs";
import { sToBytes32 } from "../common";

// if length is not 64 pad with 0
const pad = (str: string): string => (str.length === 64 ? str : pad("0" + str));

export async function getCredentials() {
  const signer = new ethers.Wallet("0x" + process.env.PRIVATE_KEY);
  const identity = await createIdentity(
    (msg) => signer.signMessage(msg),
    "Github"
  );
  console.log("ID COMMITMENT: " + pad(identity.getCommitment().toString(16)));
  console.log(
    "ID KEY: " +
      pad(
        poseidon([identity.getNullifier(), identity.getTrapdoor()]).toString(16)
      )
  );
  return identity;
}

export async function getProof() {
  const identity = await getCredentials();
  const proof = await createProof(
    identity,
    "github",
    "bronze",
    1,
    sToBytes32("foo"),
    {
      wasmFilePath: "./test/oldSnarkArtifacts/semaphore.wasm",
      zkeyFilePath: "./test/oldSnarkArtifacts/semaphore.zkey",
    },
    "goerli"
  );
  return proof;
}
