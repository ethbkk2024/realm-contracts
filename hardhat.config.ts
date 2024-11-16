import * as dotenv from 'dotenv';

import { HardhatUserConfig, task } from 'hardhat/config';
import '@openzeppelin/hardhat-upgrades'
import '@nomicfoundation/hardhat-ethers';
import '@nomicfoundation/hardhat-toolbox';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-gas-reporter';
import 'solidity-coverage';

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.26",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    }
  },
  sourcify: {
    enabled: false
  },
  networks: {
    base_testnet: {
      url: 'https://base-sepolia-rpc.publicnode.com',
      chainId: 84532,
      // gas: 21000,
      // gasPrice: 100000000,
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    chiliz_testnet: {
      url: 'https://chiliz-spicy.publicnode.com',
      chainId: 88882,
      gas: 21000,
      gasPrice: 1000000,
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: 'USD',
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
