import {expect} from "chai";
import { Contract } from "ethers";
import {ethers} from "hardhat";

const sToBytes32 = (str: string): string => {
    return ethers.utils.formatBytes32String(str);
}

const SNARK_SCALAR_FIELD = BigInt(
    "21888242871839275222246405745257275088548364400416034343698204186575808495617"
)

const createGroupId = (provider: string, name: string): bigint => {
    const providerBytes = sToBytes32(provider);
    const nameBytes = sToBytes32(name);
    return BigInt(ethers.utils.solidityKeccak256(["bytes32", "bytes32"], [providerBytes, nameBytes])) % SNARK_SCALAR_FIELD
}

const providers = ['github', 'twitter', 'reddit'];
const tiers = ['bronze', 'silver', 'gold'];

const scaffoldInterep = async () => {
    // Deploy interep
    const InterepTest = await ethers.getContractFactory("InterepTest");
    const interepTest = await InterepTest.deploy();
    await interepTest.deployed();
    const interepAddress = interepTest.address;

    //  add all combinations of providers and tiers into an array
    const groups = providers.flatMap(provider => tiers.map(tier => {
        return {
            provider: sToBytes32(provider),
            name: sToBytes32(tier),
            root: 1,
            depth: 10,
        }
    }));
    // insert groups into interep membership contract
    const groupInsertionTx = await interepTest.updateGroups(groups);
    await groupInsertionTx.wait();

    return {interepTest, groups}
}

const scaffold = async () => {
    const {interepTest, groups} = await scaffoldInterep();
    const interepAddress = interepTest.address;

    // create valid group storage contract for rln
    const ValidGroupStorage = await ethers.getContractFactory("ValidGroupStorage");
    const filteredGroups = groups
        .filter(group => group.name !== sToBytes32('bronze'));
    const validGroupStorage = await ValidGroupStorage.deploy(interepAddress, filteredGroups);
    await validGroupStorage.deployed();
    expect(validGroupStorage.address).to.not.equal(0);

    return validGroupStorage
}

describe("Valid Group Storage", () => {
    let validGroupStorage: Contract;
    beforeEach(async () => {
        validGroupStorage = await scaffold();
    })

    it('should not deploy if an invalid group is passed in constructor', async () => {
        const {interepTest} = await scaffoldInterep();
        const interepAddress = interepTest.address;
        
        const ValidGroupStorage = await ethers.getContractFactory("ValidGroupStorage");
        expect(ValidGroupStorage.deploy(interepAddress, [{
            provider: sToBytes32('github'),
            name: sToBytes32('diamond'),
        }])).to.be.revertedWith("[ValidGroupStorage] Invalid group");
    })

    it("should return true for valid group", async () => {
        const valid = await validGroupStorage.isValidGroup(createGroupId('github', 'silver'));
        expect(valid).to.be.true;
    });

    it("should return false for invalid group", async () => {
        const valid = await validGroupStorage.isValidGroup(createGroupId('github', 'bronze'));
        expect(valid).to.be.false;
    });
})