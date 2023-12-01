import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getUnnamedAccounts } = hre;
  const { deploy } = deployments;

  const [deployer] = await getUnnamedAccounts();

  await deploy("BinaryIMT", {
    from: deployer,
    log: true,
    libraries: {
      PoseidonT3: (await deployments.get("PoseidonT3")).address,
    },
  });
};

export default func;
func.tags = ["BinaryIMT"];
func.dependencies = ["PoseidonT3"];
