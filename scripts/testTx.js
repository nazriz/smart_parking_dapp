const { ethers } = require("hardhat");
const hre = require("hardhat");
require("dotenv").config();

const genericLargeResponse_abi = require("../ABI/GenericLargeResponse_abi.json");

const rinkebyProvider = ethers.getDefaultProvider("rinkeby");

const rinkebySigner = new ethers.Wallet(
  process.env.PRIVATE_KEY,
  rinkebyProvider
);

const responseContract = new ethers.Contract(
  "0x6A3efF8066dF9580685405DE5C8278e572A4b451",
  genericLargeResponse_abi,
  rinkebySigner
);

const test = async () => {
  let data = await responseContract.data();

  console.log(`Data is: ${data}`);

  let tx = await responseContract.requestBytes({
    gasLimit: 2100000,
    gasPrice: 8000000000,
  });

  data = await responseContract.data();

  console.log(`Data is: ${data}`);
};

test();
