import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { isDevNet } from "../common";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getUnnamedAccounts } = hre;
  const { deploy } = deployments;

  const [deployer] = await getUnnamedAccounts();

  await deploy("VerifierTest", {
    from: deployer,
    log: true,
  });
};
export default func;
func.tags = ["VerifierTest"];
// skip when running on mainnet
func.skip = async (hre: HardhatRuntimeEnvironment) => {
  if (isDevNet(hre.network.name)) {
    return false;
  }
  return true;
};
