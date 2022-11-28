import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { getGroups, isDevNet, merkleTreeDepth } from "../common";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getUnnamedAccounts } = hre;
  const { deploy } = deployments;

  const [deployer] = await getUnnamedAccounts();

  const verifierAddress = (await deployments.get("VerifierTest")).address;

  const interepTest = await deploy("InterepTest", {
    from: deployer,
    log: true,
    args: [
      [
        {
          contractAddress: verifierAddress,
          merkleTreeDepth,
        },
      ],
    ],
  });

  const contract = await hre.ethers.getContractAt(
    "InterepTest",
    interepTest.address
  );
  const groups = getGroups();
  const groupInsertionTx = await contract.updateGroups(groups);
  await groupInsertionTx.wait();
};
export default func;
func.tags = ["InterepTest"];
func.dependencies = ["VerifierTest"];
// skip when running on mainnet
func.skip = async (hre: HardhatRuntimeEnvironment) => {
  if (isDevNet(hre.network.name)) {
    return false;
  }
  return true;
};
