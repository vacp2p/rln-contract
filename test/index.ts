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

    const Token = await ethers.getContractFactory("TokenRln");
    const token = await Token.deploy(1000000000);
  
    await token.deployed();
  
    console.log("Rln token contract deployed to:", token.address);

    const RlnErc20 = await ethers.getContractFactory("RLNERC20");
    const rlnErc20 = await RlnErc20.deploy(10,20,poseidonHasher.address,token.address); //10 tokens as membership deposit
  
    await rlnErc20.deployed();
    console.log("RlnErc20 deployed to:", rlnErc20.address);
  });
});
