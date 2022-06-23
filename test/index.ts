import { expect } from "chai";
import { ethers } from "hardhat";

describe("Rln", function () {
  it("Deploying", async function () {
    const PoseidonHasher = await ethers.getContractFactory("PoseidonHasher");
    const poseidonHasher = await PoseidonHasher.deploy();
  
    await poseidonHasher.deployed();
  
    console.log("PoseidonHasher deployed to:", poseidonHasher.address);
  
    const Rln = await ethers.getContractFactory("RLN");
    const rln = await Rln.deploy(1000000000000000,20,poseidonHasher.address);
  
    await rln.deployed();
  
    console.log("Rln deployed to:", rln.address);
  });
});
