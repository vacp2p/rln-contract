import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {getValidGroups, isDevNet} from '../common';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {deployments, getUnnamedAccounts} = hre;
    const {deploy} = deployments;
    
    const [deployer] = await getUnnamedAccounts();

    if (!isDevNet(hre.network.name)) {
        throw new Error('Interep not deployed on mainnet yet.')
    }
    const interepAddress = isDevNet(hre.network.name) ? (await deployments.get('InterepTest')).address : '0x0000000000000000000000000000000000000000';
    
    await deploy('ValidGroupStorage', {
        from: deployer,
        log: true,
        args: [interepAddress, getValidGroups()]
    });
};
export default func;
func.tags = ['ValidGroupStorage'];
func.dependencies = ['InterepTest'];