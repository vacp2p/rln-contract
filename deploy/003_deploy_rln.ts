import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, DeploymentSubmission } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getUnnamedAccounts } = hre;

  const [deployer] = await getUnnamedAccounts();

  const wakuRlnRegistry = await deployments.get("WakuRlnRegistry");
  const registryContract = new hre.ethers.Contract(
    wakuRlnRegistry.address,
    wakuRlnRegistry.abi,
    hre.ethers.provider.getSigner(deployer)
  );

  const indexOfStorageToBeDeployed = await registryContract.nextStorageIndex();
  const tx = await registryContract.newStorage();
  await tx.wait();

  const poseidonHasherAddress = (await deployments.get("PoseidonHasher"))
    .address;
  const storageAddress = await registryContract.storages(
    indexOfStorageToBeDeployed
  );
  const extendedArtifact = await deployments.getExtendedArtifact("WakuRln");

  console.log("Storage address: ", storageAddress);
  const d: DeploymentSubmission = {
    abi: extendedArtifact.abi,
    address: storageAddress,
    args: [poseidonHasherAddress, indexOfStorageToBeDeployed],
    bytecode: extendedArtifact.bytecode,
    deployedBytecode: extendedArtifact.deployedBytecode,
    receipt: tx,
    transactionHash: tx.hash,
    metadata: extendedArtifact.metadata,
    solcInput: extendedArtifact.solcInput,
    devdoc: extendedArtifact.devdoc,
  };
  console.log(d);
  deployments.save(`WakuRlnStorage_${indexOfStorageToBeDeployed}`, d);
};

export default func;
func.dependencies = ["WakuRlnRegistry"];
