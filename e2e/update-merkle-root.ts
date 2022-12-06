import { BigNumberish, ethers, Signer } from "ethers";
import { sToBytes32 } from "../common";
import {
  address,
  abi,
} from "../deployments/localhost_integration/InterepTest.json";

export async function updateMerkleRoot(
  signer: Signer,
  groupProvider: string,
  groupName: string,
  merkleRoot: BigNumberish
) {
  const interepContract = new ethers.Contract(address, abi, signer);
  const tx = await interepContract.updateGroups([
    {
      provider: sToBytes32(groupProvider),
      name: sToBytes32(groupName),
      root: merkleRoot,
      depth: 20,
    },
  ]);
  await tx.wait();
  console.log("Updated Interep group Merkle Root!");
}
