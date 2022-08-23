const { getNamedAccounts, deployments, network } = require("hardhat");
const { networkConfig, developmentChains, VERIFICATION_BLOCK_CONFIRMATIONS } = require("../helper-hardhat-config");
const { autoFundCheck, verify } = require("../helper-functions");
const fs = require("fs");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log, get } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;
  //set log level to ignore non errors
  ethers.utils.Logger.setLogLevel(ethers.utils.Logger.levels.ERROR);

  const waitBlockConfirmations = developmentChains.includes(network.name) ? 1 : VERIFICATION_BLOCK_CONFIRMATIONS;
  const args = [];
  const requestParkingSpotToken = await deploy("RequestParkingSpotToken", {
    // contract: "contracts/parkingSpotAttributes.sol:ParkingSpotAttributes",
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: waitBlockConfirmations,
  });

  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...");
    await verify(requestParkingSpotToken.address, args);
  }
  log("----------------------------------------------------");
};
module.exports.tags = ["all", "request", "main"];
