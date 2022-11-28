import { utils } from "ethers";

export const sToBytes32 = (str: string): string => {
  return utils.formatBytes32String(str);
};

export const merkleTreeDepth = 10;

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
const tiers = ["bronze", "silver", "gold"];

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
  return getGroups().filter((group) => group.name !== sToBytes32("bronze"));
};
