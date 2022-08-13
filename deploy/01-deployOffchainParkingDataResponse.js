const { getNamedAccounts, deployments, network } = require("hardhat");
const { networkConfig, developmentChains, VERIFICATION_BLOCK_CONFIRMATIONS } = require("../helper-hardhat-config");
const { autoFundCheck, verify } = require("../helper-functions");
const fs = require("fs");
const ADDRESSES_FILE = "./contractAddresses/offchainParkingDataResponseAddresses.json";

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log, get } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;
  let linkTokenAddress;
  let oracle;
  let additionalMessage = "";
  //set log level to ignore non errors
  ethers.utils.Logger.setLogLevel(ethers.utils.Logger.levels.ERROR);

  if (chainId == 31337) {
    let linkToken = await get("LinkToken");
    let MockOracle = await get("MockOracle");
    linkTokenAddress = linkToken.address;
    oracle = MockOracle.address;
    additionalMessage = " --linkaddress " + linkTokenAddress;
  } else {
    linkTokenAddress = networkConfig[chainId]["linkToken"];
    oracle = networkConfig[chainId]["oracle"];
  }
  const jobId = ethers.utils.toUtf8Bytes(networkConfig[chainId]["jobId"]);
  const fee = networkConfig[chainId]["fee"];

  const waitBlockConfirmations = developmentChains.includes(network.name) ? 1 : VERIFICATION_BLOCK_CONFIRMATIONS;
  const args = [oracle, jobId, fee, linkTokenAddress];
  const offChainParkingDataResponse = await deploy("OffchainParkingDataResponse", {
    contract: "contracts/OffchainParkingDataResponse.sol:OffchainParkingDataResponse",
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: waitBlockConfirmations,
  });

  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...");
    await verify(offChainParkingDataResponse.address, args);
  }

  // Checking for funding...
  if (networkConfig.fundAmount && networkConfig.fundAmount > 0) {
    log("Funding with LINK...");
    if (await autoFundCheck(offChainParkingDataResponse.address, network.name, linkTokenAddress, additionalMessage)) {
      await hre.run("fund-link", {
        contract: offChainParkingDataResponse.address,
        linkaddress: linkTokenAddress,
      });
    } else {
      log("Contract already has LINK!");
    }
  }

  // Update contract addresses
  const chainNumber = network.config.chainId.toString();
  const currentAddresses = JSON.parse(fs.readFileSync(ADDRESSES_FILE, "utf-8"));
  if (chainNumber in currentAddresses) {
    if (!currentAddresses[chainNumber].includes(offChainParkingDataResponse.address)) {
      currentAddresses[chainNumber].push(offChainParkingDataResponse.address);
    }
  }
  {
    currentAddresses[chainNumber] = [offChainParkingDataResponse.address];
  }

  fs.writeFileSync(ADDRESSES_FILE, JSON.stringify(currentAddresses));

  log("Run API Consumer contract with following command:");
  const networkName = network.name == "hardhat" ? "localhost" : network.name;
  log(`yarn hardhat request-data --contract ${offChainParkingDataResponse.address} --network ${networkName}`);
  log("----------------------------------------------------");
};
module.exports.tags = ["all", "api", "main"];
