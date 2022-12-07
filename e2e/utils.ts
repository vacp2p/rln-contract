import createIdentity from "@interep/identity";
import createProof from "@interep/proof";
import { ethers } from "ethers";
import { Network } from "@interep/api";
// @ts-ignore
import { poseidon } from "circomlibjs";
import { sToBytes32 } from "../common";

// if length is not 64 pad with 0
const pad = (str: string): string => (str.length === 64 ? str : pad("0" + str));

const capitalize = (str: string): string =>
  str.charAt(0).toUpperCase() + str.slice(1);

export async function getCredentials(groupProvider: string) {
  const signer = new ethers.Wallet("0x" + process.env.PRIVATE_KEY);
  const identity = await createIdentity(
    (msg) => signer.signMessage(msg),
    capitalize(groupProvider)
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

export async function getProof(
  groupProvider: string,
  groupTier: string,
  network: Network
) {
  const identity = await getCredentials(groupProvider);
  const proof = await createProof(
    identity,
    groupProvider,
    groupTier,
    1,
    sToBytes32("foo"),
    {
      wasmFilePath: "./test/oldSnarkArtifacts/semaphore.wasm",
      zkeyFilePath: "./test/oldSnarkArtifacts/semaphore.zkey",
    },
    network
  );
  return proof;
}
