import { ethers } from "hardhat";

describe("Rln", function () {
  it("Deploying", async function () {
    const PoseidonHasher = await ethers.getContractFactory("PoseidonHasher");
    const poseidonHasher = await PoseidonHasher.deploy();
  
    await poseidonHasher.deployed();
  
    console.log("PoseidonHasher deployed to:", poseidonHasher.address);

    const Rln = await ethers.getContractFactory("RLN");
    const rln = await Rln.deploy(1000000000000000, 20, poseidonHasher.address);
  
    await rln.deployed();

    console.log("Rln deployed to:", rln.address);
    
    const price = await rln.MEMBERSHIP_DEPOSIT();

    // A valid pair of (id_secret, id_commitment)
    const id_secret = "0x2a09a9fd93c590c26b91effbb2499f07e8f7aa12e2b4940a3aed2411cb65e11c"
    const id_commitment = "0x0c3ac305f6a4fe9bfeb3eba978bc876e2a99208b8b56c80160cfb54ba8f02368"

    // We attempt to register and withdraw the commitment (tree index is 0 since the tree is empty)
    await rln.register(id_commitment, {value: price});
    await rln.withdraw(id_secret, "0", "0x000000000000000000000000000000000000dead");

    rln.on('MemberRegistered', function (id_commitment, tree_index) {
        console.log(`A new member registered:`);
        console.log(`- id_commitment: ${id_commitment}`);
        console.log(`- tree_index: ${tree_index}`);
    });

    rln.on('MemberWithdrawn', function (id_commitment, tree_index) {
        console.log(`A member withdrawn its membership fee:`);
        console.log(`- id_commitment: ${id_commitment}`);
        console.log(`- tree_index: ${tree_index}`);
    });
    

  });
});
