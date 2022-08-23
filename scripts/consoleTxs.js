const { getNamedAccounts, deployments, network } = require("hardhat");
const hre = require("hardhat");
require("dotenv").config();
const { deployer } = getNamedAccounts();

async function main() {
  const accounts = await ethers.provider.listAccounts();
  const offchain = await (
    await ethers.getContractFactory("contracts/OffchainParkingDataResponse.sol:OffchainParkingDataResponse")
  ).attach("0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0");
  const token = await (
    await ethers.getContractFactory("contracts/ParkingSpotToken.sol:ParkingSpotToken")
  ).attach("0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9");
  const attributes = await (
    await ethers.getContractFactory("ParkingSpotAttributes")
  ).attach("0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9");

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
  console.log("approved for dummy contract:");
  console.log(
    await token.isApprovedForAll(
      "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
      "0x2EDca11fE8d9fBcA1258AeBb6e9436D67966eACD"
    )
  );
  console.log("Setting availability....");
  await attributes.setSpotAvailability(1, 1);
  console.log("Current availability:");
  console.log(await attributes.checkSpotAvailability(1));

  console.log("approved for dummy contract:");
  console.log(
    await token.isApprovedForAll(
      "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
      "0x2EDca11fE8d9fBcA1258AeBb6e9436D67966eACD"
    )
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
