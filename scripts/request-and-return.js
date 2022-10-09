const { providers } = require("ethers");
const { getNamedAccounts, deployments, network, artifacts } = require("hardhat");
const hre = require("hardhat");
const { BlockList } = require("net");
require("dotenv").config();
const { deployer } = getNamedAccounts();

async function main() {
  const provider = ethers.provider;
  const [addr1, addr2, addr3] = await ethers.getSigners();
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
  console.log("Requesting fake bytes....");
  await offchain.connect(addr1).fakeFulfillBytes();
  console.log("done!");
  console.log("Minting parking spot token...");
  await token.mintParkingSpot(addr1.address, 0);
  console.log("minted!");
  console.log("checking owner...");
  console.log(await token.ownerOf(1));
  console.log("Current availability:");
  console.log(await attributes.checkSpotAvailability(1));

  console.log("Setting availability....");
  await attributes.setSpotAvailability(1, 1);
  console.log("Setting token rate...");
  await attributes.setPricePerHour(1, 5);

  console.log("Checking token owner");
  console.log(await token.ownerOf(1));

  //========
  console.log("Setting availability....");
  await attributes.setSpotAvailability(1, 1);
  console.log("Current availability:");
  console.log(await attributes.checkSpotAvailability(1));

  console.log("Setting start time 0900, end time 1700");
  await attributes.connect(addr1).setSpotPermittedParkingTime(1, 09, 00, 23, 00);
  console.log("onchain start time:");
  console.log(await attributes.checkSpotPermittedParkingStartTime(1));
  console.log("onchain end time:");
  console.log(await attributes.checkSpotPermittedParkingEndTime(1));

  console.log("Parking spot owners map");
  console.log(await token._parkingSpotOwners(1));

  console.log("Approving for request contract...");
  await token.connect(addr1).setApprovalForRequestContract(1, "0x0165878A594ca255338adfa4d48449f69242Eb8F", true);

  console.log("approved for request contract:");
  console.log(await token.isApprovedForRequestContract(1, "0x0165878A594ca255338adfa4d48449f69242Eb8F"));

  console.log("setting parking spot timezone... ");
  await attributes.setParkingSpotTimezone(1, 1, 11);
  console.log("timezone set to:");
  console.log(await attributes.parkingSpotTimeZone(1, 0));
  console.log(await attributes.parkingSpotTimeZone(1, 1));

  console.log("depositing 0.03 eth...");
  await requestSpot.connect(addr2).deposit({ value: ethers.utils.parseUnits("0.03", "ether") });

  console.log("requesting token...");
  await requestSpot.connect(addr2).requestParkingSpotToken(1, 22, 15, 22, 30);

  console.log("requested times");
  console.log(await requestSpot.requestedParkingTimes(1, 0));
  console.log(await requestSpot.requestedParkingTimes(1, 1));

  console.log("checking owner...");
  console.log(await token.ownerOf(1));

  console.log((await ethers.provider.getBlock("latest")).timestamp);

  await ethers.provider.send("evm_mine", [1665142244]);

  console.log((await ethers.provider.getBlock("latest")).timestamp);

  console.log("attempting to return token...");
  await requestSpot.returnParkingSpotToken(1);

  console.log("checking owner...");
  console.log(await token.ownerOf(1));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
