import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getUnnamedAccounts } = hre;
  const { deploy } = deployments;

  const [deployer] = await getUnnamedAccounts();

  const deployRes = await deploy("PoseidonT3", {
    from: deployer,
    log: true,
  });

  await deploy("PoseidonHasher", {
    from: deployer,
    log: true,
    libraries: {
      PoseidonT3: deployRes.address,
    },
  });
};
export default func;
func.tags = ["PoseidonHasher"];
