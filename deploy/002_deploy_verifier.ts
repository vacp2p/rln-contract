import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { useRealVerifier } from "../common";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getUnnamedAccounts } = hre;
  const { deploy } = deployments;

  const [deployer] = await getUnnamedAccounts();

  await deploy("Verifier20", {
    from: deployer,
    log: true,
  });
};
export default func;
func.tags = ["Verifier20"];
// skip when running on mainnet
func.skip = async (hre: HardhatRuntimeEnvironment) => {
  if (useRealVerifier(hre.network.name)) {
    return false;
  }
  return true;
};
