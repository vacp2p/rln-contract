import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {
    getGroups,
    isDevNet
} from '../common';


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {deployments, getUnnamedAccounts} = hre;
    const {deploy} = deployments;
    
    const [deployer] = await getUnnamedAccounts();
    
    const interepTest = await deploy('InterepTest', {
        from: deployer,
        log: true,
        args: [],
    });

    const contract = await hre.ethers.getContractAt('InterepTest', interepTest.address);
    const groups = getGroups();
    const groupInsertionTx = await contract.updateGroups(groups);
    await groupInsertionTx.wait();
    
};
export default func;
func.tags = ['InterepTest'];
// skip when running on mainnet
func.skip = async (hre: HardhatRuntimeEnvironment) => {
    if (isDevNet(hre.network.name)) {
        return false;
    }
    return true;
}