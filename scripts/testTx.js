const { ethers } = require("hardhat");
const hre = require("hardhat");
require("dotenv").config();

const genericLargeResponse_abi = require("../ABI/GenericLargeResponse_abi.json");

const rinkebyProvider = ethers.getDefaultProvider("rinkeby");

const rinkebySigner = new ethers.Wallet(process.env.DEMO_PRIVATE_KEY, rinkebyProvider);

const responseContract = new ethers.Contract(
  "0x2835A4B1d3e903ca8a4071942Dda1b6F9165ace5",
  genericLargeResponse_abi,
  rinkebySigner
);

const test = async () => {
  let data = await responseContract.parking_spot_location();

  console.log(`Data is: ${data}`);
  // console.log(rinkebySigner.address);

  // let tx = await responseContract.requestOffchainParkingSpotData({
  //   gasLimit: 2100000,
  //   gasPrice: 8000000000,
  // });

  data = await responseContract.data();

  console.log(`Data is: ${data}`);
};

test();

const offchain = await (
  await ethers.getContractFactory("contracts/OffchainParkingDataResponse.sol:OffchainParkingDataResponse")
).attach("0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0");
const token = await (
  await ethers.getContractFactory("contracts/ParkingSpotToken.sol:ParkingSpotToken")
).attach("0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9");
const attributes = await (
  await ethers.getContractFactory("ParkingSpotAttributes")
).attach("0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9");
