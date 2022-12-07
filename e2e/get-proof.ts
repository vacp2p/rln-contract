async function main() {
  const { getProof } = await import("./utils");
  const proof = await getProof();
  console.log(proof);
  console.log("SOLIDITY PROOF: ", JSON.stringify(proof.solidityProof));
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
