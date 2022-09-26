import { ethers } from "hardhat";

async function main() {
  // Deploy STT (it's also deployed at 0x3d6afaa395c31fcd391fe3d562e75fe9e8ec7e6a in Goerli)
  const MiniMeTokenFactory = await ethers.getContractFactory("MiniMeTokenFactory");
  const minimeTokenFactory = await MiniMeTokenFactory.deploy();
  await minimeTokenFactory.deployed();
  console.log("minimeTokenFactory deployed to:", minimeTokenFactory.address);

  const STT = await ethers.getContractFactory("STT");
  const stt = await STT.deploy(minimeTokenFactory.address);
  await stt.deployed();
  console.log("STT deployed to:", stt.address);

  // Generating 1337 STT tokens
  let stt1337 = ethers.utils.parseUnits("1337", "ether");
  await stt.generateTokens("0x00000000000000000000000000000000AABBCCDD", stt1337);
  console.log("Account balance: ", await stt.balanceOf("0x00000000000000000000000000000000AABBCCDD"))
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
