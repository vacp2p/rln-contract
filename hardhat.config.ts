import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import "hardhat-gas-reporter";
import "solidity-coverage";
import { NetworksUserConfig } from "hardhat/types";

dotenv.config();
const {GOERLI_URL,PRIVATE_KEY} = process.env;

const getNetworkConfig = (): NetworksUserConfig | undefined => {
    if (GOERLI_URL && PRIVATE_KEY) {
        return {
            goerli: {
              url: GOERLI_URL,
              accounts: [PRIVATE_KEY],
            }
        };
    }
    return undefined;
}

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    compilers: [{
      version: "0.8.4",
    }, {
      version: "0.8.15"
    }],
  },
  networks: getNetworkConfig()
};

export default config;