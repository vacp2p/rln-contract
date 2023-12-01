import { expect } from "chai";
import { ethers, deployments } from "hardhat";

describe("PoseidonT3", () => {
  beforeEach(async () => {
    await deployments.fixture(["PoseidonT3"]);
  });

  it("should hash correctly", async function () {
    const poseidonHasher = await ethers.getContract("PoseidonT3");

    // We test hashing for a random number
    const hash = await poseidonHasher.hash([
      "19014214495641488759237505126948346942972912379615652741039992445865937985820",
      "0",
    ]);

    expect(hash.toHexString()).to.eql(
      "0x1d1ac5f6cf23b059eb43c657ce622b614b5960ea4b23f92d428d3e42982a4e13"
    );
  });
});
