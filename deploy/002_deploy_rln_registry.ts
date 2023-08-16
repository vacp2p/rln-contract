import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getUnnamedAccounts } = hre;
  const { deploy } = deployments;

  const [deployer] = await getUnnamedAccounts();

  const poseidonHasherAddress = (await deployments.get("PoseidonHasher"))
    .address;

  await deploy("WakuRlnRegistry", {
    from: deployer,
    log: true,
    args: [poseidonHasherAddress],
  });
};

export default func;
func.tags = ["WakuRlnRegistry"];
func.dependencies = ["PoseidonHasher"];
