import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { getInterepAddress, getValidGroups, isDevNet } from "../common";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getUnnamedAccounts } = hre;
  const { deploy } = deployments;

  const [deployer] = await getUnnamedAccounts();

  const interepAddress = isDevNet(hre.network.name)
    ? (await deployments.get("InterepTest")).address
    : getInterepAddress(hre.network.name);

  await deploy("ValidGroupStorage", {
    from: deployer,
    log: true,
    args: [interepAddress, getValidGroups()],
  });
};
export default func;
func.tags = ["ValidGroupStorage"];
func.dependencies = ["InterepTest"];
