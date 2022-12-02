export const devNets = ["hardhat", "localhost"];

export const testNets = ["goerli"];

export const prodNets = ["mainnet"];

export const isDevNet = (networkName: string) => devNets.includes(networkName);

export const isTestNet = (networkName: string) =>
  testNets.includes(networkName);

export const isProdNet = (networkName: string) =>
  prodNets.includes(networkName);

export const getInterepAddress = (networkName: string) => {
  switch (networkName) {
    case "mainnet":
      throw new Error("Interep not deployed on mainnet yet.");
    case "goerli":
      return "0x9f44be9F69aF1e049dCeCDb2d9296f36C49Ceafb";
    default:
      throw new Error(`Unknown network name: ${networkName}`);
  }
};
