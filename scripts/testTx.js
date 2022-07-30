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
