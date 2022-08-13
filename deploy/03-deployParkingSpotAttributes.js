const { getNamedAccounts, deployments, network } = require("hardhat");
const { networkConfig, developmentChains, VERIFICATION_BLOCK_CONFIRMATIONS } = require("../helper-hardhat-config");
const { autoFundCheck, verify } = require("../helper-functions");
const fs = require("fs");
const ADDRESSES_FILE = "./contractAddresses/parkingSpotTokenAddresses.json";

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log, get } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;
  let offchainParkingDataResponseAddress;
  //set log level to ignore non errors
  ethers.utils.Logger.setLogLevel(ethers.utils.Logger.levels.ERROR);

  const currentAddresses = JSON.parse(fs.readFileSync(ADDRESSES_FILE, "utf-8"));
  offchainParkingDataResponseAddress = currentAddresses[chainId][0];
  console.log(offchainParkingDataResponseAddress);

  const waitBlockConfirmations = developmentChains.includes(network.name) ? 1 : VERIFICATION_BLOCK_CONFIRMATIONS;
  const args = [offchainParkingDataResponseAddress];
  const parkingSpotAttributes = await deploy("ParkingSpotAttributes", {
    // contract: "contracts/parkingSpotAttributes.sol:ParkingSpotAttributes",
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: waitBlockConfirmations,
  });

  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...");
    await verify(parkingSpotAttributes.address, args);
  }

  log("Run API Consumer contract with following command:");
  const networkName = network.name == "hardhat" ? "localhost" : network.name;
  log(`yarn hardhat request-data --contract ${parkingSpotAttributes.address} --network ${networkName}`);
  log("----------------------------------------------------");
};
module.exports.tags = ["all", "token", "main"];
