import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getUnnamedAccounts } = hre;
  const { deploy } = deployments;

  const [deployer] = await getUnnamedAccounts();

  const poseidonHasherAddress = (await deployments.get("PoseidonHasher"))
    .address;
  const rlnVerifierAddress = (await deployments.get("Verifier")).address;

  const deployRes = await deploy("BinaryIMT", {
    from: deployer,
    log: true,
    libraries: {
      PoseidonT3: (await deployments.get("PoseidonT3")).address,
    },
  });

  await deploy("RLN", {
    from: deployer,
    log: true,
    args: [1000000000000000, 20, poseidonHasherAddress, rlnVerifierAddress],
    libraries: {
      BinaryIMT: deployRes.address,
    },
  });
};

export default func;
func.tags = ["Rln"];
func.dependencies = ["PoseidonHasher", "RlnVerifier", "BinaryIMT"];
