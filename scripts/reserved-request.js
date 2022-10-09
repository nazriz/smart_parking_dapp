const { providers } = require("ethers");
const { getNamedAccounts, deployments, network, artifacts } = require("hardhat");
const hre = require("hardhat");
const { BlockList } = require("net");
require("dotenv").config();
const { deployer } = getNamedAccounts();

async function main() {
  const provider = ethers.provider;
  const [addr1, addr2, addr3, addr4, addr5] = await ethers.getSigners();
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

  console.log("depositing 0.03 eth...");
  await requestSpot.connect(addr2).deposit({ value: ethers.utils.parseUnits("0.03", "ether") });
  await requestSpot.connect(addr3).deposit({ value: ethers.utils.parseUnits("0.03", "ether") });
  await requestSpot.connect(addr4).deposit({ value: ethers.utils.parseUnits("0.03", "ether") });
  await requestSpot.connect(addr5).deposit({ value: ethers.utils.parseUnits("0.03", "ether") });

  // console.log("requesting token...");
  // await requestSpot.connect(addr2).requestParkingSpotToken(1, 22, 15, 22, 30);

  console.log("reserving spot from addr2:");
  await requestSpot.connect(addr2).reserveParkingSpotToken(1, 01, 00, 01, 59);
  console.log("reserved times mapping:");
  console.log(await requestSpot.getReservedParkingTimes(1, 0));

  console.log("reserving spot from addr3:");
  await requestSpot.connect(addr3).reserveParkingSpotToken(1, 04, 30, 4, 59);
  console.log("reserved times mapping:");
  console.log(await requestSpot.getReservedParkingTimes(1, 0));
  console.log(await requestSpot.getReservedParkingTimes(1, 1));

  console.log("reserving spot from addr4:");
  await requestSpot.connect(addr4).reserveParkingSpotToken(1, 02, 30, 02, 59);
  console.log(await requestSpot.getReservedParkingTimes(1, 0));
  console.log(await requestSpot.getReservedParkingTimes(1, 1));
  console.log(await requestSpot.getReservedParkingTimes(1, 2));

  console.log("reserving spot from addr5:");

  await requestSpot.connect(addr5).reserveParkingSpotToken(1, 03, 00, 03, 30);

  console.log(await requestSpot.getReservedParkingTimes(1, 0));
  console.log(await requestSpot.getReservedParkingTimes(1, 1));
  console.log(await requestSpot.getReservedParkingTimes(1, 2));
  console.log(await requestSpot.getReservedParkingTimes(1, 3));

  console.log("checking owner...");
  console.log(await token.ownerOf(1));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
