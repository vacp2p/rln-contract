import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getUnnamedAccounts } = hre;
  const { deploy } = deployments;

  const [deployer] = await getUnnamedAccounts();

  const rlnVerifierAddress = (await deployments.get("Verifier")).address;

  const binaryIMTAddress = (await deployments.get("BinaryIMT")).address;

  await deploy("RLN", {
    from: deployer,
    log: true,
    args: [1000000000000000, 20, rlnVerifierAddress],
    libraries: {
      BinaryIMT: binaryIMTAddress,
    },
  });
};

export default func;
func.tags = ["RLN"];
func.dependencies = ["PoseidonT3", "RlnVerifier", "BinaryIMT"];
