import {expect} from "chai";
import {ethers, deployments} from "hardhat";
import {sToBytes32, createGroupId} from '../common';


describe("Valid Group Storage", () => {
    beforeEach(async () => {
        await deployments.fixture(['ValidGroupStorage']);
    })

    it('should not deploy if an invalid group is passed in constructor', async () => {
        const interepTest = await ethers.getContract('InterepTest');
        const interepAddress = interepTest.address;
        
        const ValidGroupStorage = await ethers.getContractFactory("ValidGroupStorage");
        expect(ValidGroupStorage.deploy(interepAddress, [{
            provider: sToBytes32('github'),
            name: sToBytes32('diamond'),
        }])).to.be.revertedWith("[ValidGroupStorage] Invalid group");
    })

    it("should return true for valid group", async () => {
        const validGroupStorage = await ethers.getContract('ValidGroupStorage');
        const valid = await validGroupStorage.isValidGroup(createGroupId('github', 'silver'));
        expect(valid).to.be.true;
    });

    it("should return false for invalid group", async () => {
        const validGroupStorage = await ethers.getContract('ValidGroupStorage');
        const valid = await validGroupStorage.isValidGroup(createGroupId('github', 'bronze'));
        expect(valid).to.be.false;
    });
})