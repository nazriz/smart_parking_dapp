const { providers } = require("ethers");
const { getNamedAccounts, deployments, network } = require("hardhat");
const hre = require("hardhat");
require("dotenv").config();
const { deployer } = getNamedAccounts();

async function main() {
  const provider = ethers.provider;
  const [addr1, addr2] = await ethers.getSigners();
  const offchain = await (
    await ethers.getContractFactory("contracts/OffchainParkingDataResponse.sol:OffchainParkingDataResponse")
  ).attach("0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0");
  const token = await (
    await ethers.getContractFactory("contracts/ParkingSpotToken.sol:ParkingSpotToken")
  ).attach("0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9");
  const attributes = await (
    await ethers.getContractFactory("contracts/ParkingSpotAttributes.sol:ParkingSpotAttributes")
  ).attach("0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9");

  const requestSpot = await (
    await ethers.getContractFactory("RequestParkingSpotToken")
  ).attach("0x5FC8d32690cc91D4c39d9d3abcBD16989F875707");

  // Mint Token from addr1
  console.log("Requesting fake bytes....");
  await offchain.fakeFulfillBytes();
  console.log("done!");
  console.log("Minting parking spot token...");
  await token.mintParkingSpot("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", 0);
  console.log("minted!");
  console.log("checking owner...");
  console.log(await token.ownerOf(1));
  console.log("Current availability:");
  console.log(await attributes.checkSpotAvailability(1));
  console.log("approved for request contract:");
  console.log(
    await token.isApprovedForAll(
      "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
      "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707"
    )
  );
  console.log("Approving request contract...");
  await token.setApprovalForAll("0x5FC8d32690cc91D4c39d9d3abcBD16989F875707", true);
  console.log("Setting availability....");
  await attributes.setSpotAvailability(1, 1);
  console.log("Current availability:");
  console.log(await attributes.checkSpotAvailability(1));

  console.log("Setting start time 0900, end time 1700");
  await attributes.setSpotPermittedParkingTime(1, 09, 30, 17, 30);
  console.log("onchain start time:");
  console.log(await attributes.checkSpotPermittedParkingStartTime(1));
  console.log("onchain end time:");
  console.log(await attributes.checkSpotPermittedParkingEndTime(1));

  console.log("approved for request contract:");
  console.log(
    await token.isApprovedForAll(
      "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
      "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707"
    )
  );

  console.log("converted approved unix time:");
  await requestSpot.checkAndConvertAvailabilityTime(1);
  console.log(await requestSpot.permittedStartTimeUnix());

  // await requestSpot.connect(addr2).deposit({ value: ethers.utils.parseUnits("2", "ether") });
  // console.log("depositing 1 eth...");
  // console.log("Balance of RequestParkingSpot:");
  // console.log(await provider.getBalance(requestSpot.address));
  // console.log("mapping balance");
  // console.log(await requestSpot.depositors(addr2.address));

  // console.log("requesting token...");
  // await requestSpot.connect(addr2).requestParkingSpotToken(1);

  // console.log("checking owner...");
  // console.log(await token.ownerOf(1));

  // const timeStamp = (await ethers.provider.getBlock("latest")).timestamp;
  // console.log(timeStamp);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

//   await requestSpot.connect(addr2).withdraw(ethers.utils.parseUnits("1", "ether"), {
//     gasLimit: 2100000,
//     gasPrice: 8000000000,
//   });
//   console.log("Withdrawing 1 eth...");
//   console.log("Balance of RequestParkingSpot:");
//   console.log(await provider.getBalance(requestSpot.address));
//   console.log("mapping balance");
//   console.log(await requestSpot.depositors(addr2.address));
