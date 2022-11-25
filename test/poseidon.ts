import { expect } from "chai";
import { ethers, deployments } from "hardhat";

describe("PoseidonHasher", () => {
  beforeEach(async () => {
    await deployments.fixture(["PoseidonHasher"]);
  });

  it("should hash correctly", async function () {
    const poseidonHasher = await ethers.getContract("PoseidonHasher");
  
    // We test hashing for a random number
    const hash = await poseidonHasher.hash("19014214495641488759237505126948346942972912379615652741039992445865937985820");
 
    expect(hash._hex).to.eql("0x0c3ac305f6a4fe9bfeb3eba978bc876e2a99208b8b56c80160cfb54ba8f02368");
  });
});
