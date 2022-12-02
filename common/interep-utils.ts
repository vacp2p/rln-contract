import { Signer, utils } from "ethers";
import createIdentity from "@interep/identity";
import { Group, Member } from "@semaphore-protocol/group";
import { generateProof, packToSolidityProof } from "@semaphore-protocol/proof";
import type { Identity } from "@semaphore-protocol/identity";
// import createProof from '@interep/proof'
import type { SnarkArtifacts } from "@interep/proof/dist/types/types";

export const sToBytes32 = (str: string): string => {
  return utils.formatBytes32String(str);
};

// zerokit can only use 15, 19, and 20 depth
export const merkleTreeDepth = 20;

export const SNARK_SCALAR_FIELD = BigInt(
  "21888242871839275222246405745257275088548364400416034343698204186575808495617"
);

export const createGroupId = (provider: string, name: string): bigint => {
  const providerBytes = sToBytes32(provider);
  const nameBytes = sToBytes32(name);
  return (
    BigInt(
      utils.solidityKeccak256(
        ["bytes32", "bytes32"],
        [providerBytes, nameBytes]
      )
    ) % SNARK_SCALAR_FIELD
  );
};

const providers = ["github", "twitter", "reddit"];
const tiers = ["bronze", "silver", "gold", "unrated"];

// from goerli.interep.link
const validGroups: {
  [key: string]: string[];
} = {
  github: ["gold", "bronze", "unrated"],
  reddit: ["unrated"],
};

export const getGroups = () => {
  return providers.flatMap((provider) =>
    tiers.map((tier) => {
      return {
        provider: sToBytes32(provider),
        name: sToBytes32(tier),
        root: 1,
        depth: merkleTreeDepth,
      };
    })
  );
};

export const getValidGroups = () => {
  const returnArr = [];
  for (const provider of Object.keys(validGroups)) {
    for (const tier of validGroups[provider]) {
      returnArr.push({
        provider: sToBytes32(provider),
        name: sToBytes32(tier),
        root: 1,
        depth: merkleTreeDepth,
      });
    }
  }
  return returnArr;
};

export const createInterepIdentity = (signer: Signer, provider: string) => {
  if (!providers.includes(provider))
    throw new Error(`Invalid provider: ${provider}`);

  const sign = (message: string) => signer.signMessage(message);
  return createIdentity(sign, provider);
};

interface ProofCreationArgs {
  identity: Identity;
  members: Member[];
  groupProvider: typeof providers[0];
  groupTier: typeof tiers[0];
  externalNullifier: number;
  signal: string;
  snarkArtifacts: SnarkArtifacts;
}

// Similar to https://github.com/interep-project/interep.js/blob/ae7d19f560a63fef08b71ecba7a926729538011c/packages/proof/src/createProof.ts#L21,
// but without the api interactions
// Note: An aribitrary set of members is passed in, without validation
// when this function is called, ensure that the membership set passed in is a valid representation of onchain membership
export const createInterepProof = async (args: ProofCreationArgs) => {
  const group = new Group(merkleTreeDepth);

  const idCommitment = args.identity.getCommitment();

  group.addMembers(args.members);

  const memberIndex = group.indexOf(idCommitment);
  if (memberIndex === -1) {
    throw new Error("The semaphore identity is not yet verifiable onchain");
  }

  const merkleProof = group.generateProofOfMembership(memberIndex);

  const { publicSignals, proof } = await generateProof(
    args.identity,
    merkleProof,
    BigInt(args.externalNullifier),
    args.signal,
    args.snarkArtifacts
  );

  const solidityProof = packToSolidityProof(proof);
  const groupId = createGroupId(args.groupProvider, args.groupTier).toString();

  return {
    groupId,
    signal: args.signal,
    publicSignals,
    proof,
    solidityProof,
  };
};
