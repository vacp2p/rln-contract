async function main() {
  const { getProof } = await import("./utils");
  const proof = await getProof();
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
    process.exit(1);
  });
