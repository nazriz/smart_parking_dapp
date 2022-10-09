const { providers } = require("ethers");
const { getNamedAccounts, deployments, network, artifacts } = require("hardhat");
const hre = require("hardhat");
const { BlockList } = require("net");
require("dotenv").config();
const { deployer } = getNamedAccounts();

async function main() {
  const provider = ethers.provider;
  const [addr1, addr2, addr3, addr4] = await ethers.getSigners();
  const offchain = await (
    await ethers.getContractFactory("contracts/OffchainParkingDataResponse.sol:OffchainParkingDataResponse")
  ).attach("0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9");
  const token = await (
    await ethers.getContractFactory("contracts/ParkingSpotToken.sol:ParkingSpotToken")
  ).attach("0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9");
  const attributes = await (
    await ethers.getContractFactory("contracts/ParkingSpotAttributes.sol:ParkingSpotAttributes")
  ).attach("0x5FC8d32690cc91D4c39d9d3abcBD16989F875707");

  const requestSpot = await (
    await ethers.getContractFactory("contracts/RequestParkingSpotToken.sol:RequestParkingSpotToken")
  ).attach("0x0165878A594ca255338adfa4d48449f69242Eb8F");

  const aggV3 = await (
    await ethers.getContractFactory("MockV3Aggregator")
  ).attach("0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512");

  // Mint Token from addr1
  await offchain.connect(addr1).fakeFulfillBytes();
  await token.mintParkingSpot(addr1.address, 0);
  await attributes.setSpotAvailability(1, 1);
  await attributes.setPricePerHour(1, 5);
  await attributes.connect(addr1).setSpotPermittedParkingTime(1, 09, 00, 23, 00);
  await token.connect(addr1).setApprovalForRequestContract(1, "0x0165878A594ca255338adfa4d48449f69242Eb8F", true);
  await attributes.setParkingSpotTimezone(1, 1, 11);
  //Mint Token from addr3
  await offchain.connect(addr3).fakeFulfillBytes();
  await token.mintParkingSpot(addr3.address, 0);
  await attributes.connect(addr3).setSpotAvailability(2, 1);
  await attributes.connect(addr3).setPricePerHour(2, 5);
  await attributes.connect(addr3).setSpotPermittedParkingTime(2, 09, 00, 23, 00);
  await token.connect(addr3).setApprovalForRequestContract(2, "0x0165878A594ca255338adfa4d48449f69242Eb8F", true);
  await attributes.setParkingSpotTimezone(2, 1, 11);

  // Prepare and request address 2
  await requestSpot.connect(addr2).deposit({ value: ethers.utils.parseUnits("0.03", "ether") });
  console.log("requesting token...");
  await requestSpot.connect(addr2).requestParkingSpotToken(1, 11, 40, 11, 42);
  console.log("active sessions array:");
  console.log(await requestSpot.activeSessions(0));
  console.log("requested times");
  console.log(await requestSpot.requestedParkingTimes(1, 0));
  console.log(await requestSpot.requestedParkingTimes(1, 1));

  console.log("checking owner of token id 1:");
  console.log(await token.ownerOf(1));

  // Prepare and request address 4
  // console.log(await provider.getBalance(addr4.address));

  await requestSpot.connect(addr4).deposit({ value: ethers.utils.parseUnits("0.03", "ether") });
  console.log("requesting token...");
  // console.log(await provider.getBalance(addr4.address));

  await requestSpot.connect(addr4).requestParkingSpotToken(2, 11, 30, 17, 15);

  console.log("active sessions array:");
  console.log(await requestSpot.activeSessions(0));
  console.log(await requestSpot.activeSessions(1));

  console.log((await ethers.provider.getBlock("latest")).timestamp);
  await ethers.provider.send("evm_mine", [1665190216]);

  // console.log((await ethers.provider.getBlock("latest")).timestamp);

  console.log("attempting to return via upkeep...");
  await requestSpot.checkIfParkingSessionOver();

  console.log("active sessions array:");
  console.log(await requestSpot.activeSessions(0));

  // console.log("attempting to return token...");
  // await requestSpot.returnParkingSpotToken(1);

  console.log("checking owner...");
  console.log(await token.ownerOf(2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
