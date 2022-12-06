import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import {
  getGroups,
  isDevNet,
  merkleTreeDepth,
  useRealVerifier,
} from "../common";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getUnnamedAccounts } = hre;
  const { deploy } = deployments;

  const [deployer] = await getUnnamedAccounts();

  let verifierAddress: string;
  if (useRealVerifier(hre.network.name)) {
    verifierAddress = (await deployments.get("Verifier20")).address;
  } else {
    verifierAddress = (await deployments.get("VerifierTest")).address;
  }

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
func.dependencies = ["VerifierTest", "Verifier20"];
// skip when running on mainnet
func.skip = async (hre: HardhatRuntimeEnvironment) => {
  if (isDevNet(hre.network.name) || useRealVerifier(hre.network.name)) {
    return false;
  }
  return true;
};
