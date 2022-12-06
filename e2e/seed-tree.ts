import { Contract, ethers } from "ethers";

// Only meant to be ran locally
export async function seedTree(rlnContract: Contract) {
  const price = await rlnContract.MEMBERSHIP_DEPOSIT();
  for (let i = 0; i < 10; i++) {
    const idCommitment = `0x0c3ac305f6a4fe9bfeb3eba978bc876e2a99208b8b56c80160cfb54ba8f${i}234f`;
    console.log(`Seeding ${idCommitment}`);
    const tx = await rlnContract["register(uint256)"](
      ethers.BigNumber.from(idCommitment),
      { value: price }
    );
    await tx.wait();
  }
  console.log("Seeded tree!");
}
