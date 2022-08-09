// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
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
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
