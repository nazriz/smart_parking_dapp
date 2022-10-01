require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("hardhat-deploy");
require("@appliedblockchain/chainlink-plugins-fund-link");

/** @type import('hardhat/config').HardhatUserConfig */

const RINKEBY_RPC_URL = process.env.RINKEBY_RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;
const DEMO_PRIVATE_KEY = process.env.DEMO_PRIVATE_KEY;
const HARDHAT_PRIVATE_KEY_0 = process.env.HARDHAT_PRIVATE_KEY_0;
const GOERLI_RPC_URL = process.env.GOERLI_RPC_URL;

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.7",
      },
      {
        version: "0.8.9",
      },
      {
        version: "0.8.12",
      },
      {
        version: "0.8.0",
      },
      {
        version: "0.6.0",
      },
      {
        version: "0.6.6",
      },
      {
        version: "0.4.11",
      },
      {
        version: "0.4.24",
      },
      // {
      //   version: "0.4.8",
      // },
    ],
  },
  networks: {
    hardhat: {
      chainId: 31337,
    },
    localhost: {
      chainId: 31337,
    },
    rinkeby: {
      url: RINKEBY_RPC_URL,
      accounts: [PRIVATE_KEY],
      saveDeployments: true,
      chainId: 4,
      gas: 2100000,
      gasPrice: 8000000000,
    },
    goerli: {
      url: GOERLI_RPC_URL,
      accounts: [PRIVATE_KEY],
      chainId: 5,
      gas: 2100000,
      gasPrice: 8000000000,
    },
  },
  etherscan: {
    // yarn hardhat verify --network <NETWORK> <CONTRACT_ADDRESS> <CONSTRUCTOR_PARAMETERS>
    apiKey: ETHERSCAN_API_KEY,
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
    },
  },
};
