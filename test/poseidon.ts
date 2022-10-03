import { expect } from "chai";
import { ethers } from "hardhat";

describe("Rln", function () {
  it("Deploying", async function () {
    const PoseidonHasher = await ethers.getContractFactory("PoseidonHasher");
    const poseidonHasher = await PoseidonHasher.deploy();
  
    await poseidonHasher.deployed();
  
    console.log("PoseidonHasher deployed to:", poseidonHasher.address);
  
    // We test hashing for a random number
    const hash = await poseidonHasher.hash("19014214495641488759237505126948346942972912379615652741039992445865937985820");
 
    console.log("Hash:", hash);

    //Expect 0x0c3ac305f6a4fe9bfeb3eba978bc876e2a99208b8b56c80160cfb54ba8f02368

  });
});
