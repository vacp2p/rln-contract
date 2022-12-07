import { Network } from "@interep/api";

const groupProvider = process.argv[2] || "github";
const groupTier = process.argv[3] || "bronze";
const network = (process.argv[4] || "goerli") as Network;

async function main() {
  const { getProof } = await import("./utils");
  const proof = await getProof(groupProvider, groupTier, network);
  console.log({
    groupId: proof.groupId,
    signal: proof.signal,
    nullifierHash: proof.publicSignals.nullifierHash,
    externalNullifier: proof.publicSignals.externalNullifier,
  });
  console.log("SOLIDITY PROOF: ", JSON.stringify(proof.solidityProof));
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    console.log("Usage: yarn proof <groupProvider> <groupTier> <network>");
    process.exit(1);
  });
