const { assert, expect } = require("chai");
const { network, deployments, ethers } = require("hardhat");
const { developmentChains } = require("../../helper-hardhat-config");
const { numToBytes32 } = require("@chainlink/test-helpers/dist/src/helpers");

!developmentChains.includes(network.name)
  ? describe.skip
  : describe("offchainParkingDataResponse Unit Tests", async function () {
      let offchainParkingDataResponse, linkToken, mockOracle;

      beforeEach(async () => {
        const chainId = network.config.chainId;
        await deployments.fixture(["mocks", "api"]);
        const linkTokenContract = await deployments.get("LinkToken");
        linkToken = await ethers.getContractAt(linkTokenContract.abi, linkTokenContract.address);
        linkTokenAddress = linkToken.address;
        additionalMessage = ` --linkaddress  ${linkTokenAddress}`;
        const offchainParkingDataResponseContract = await deployments.get("OffchainParkingDataResponse");
        offchainParkingDataResponse = await ethers.getContractAt(
          offchainParkingDataResponseContract.abi,
          offchainParkingDataResponseContract.address
        );
        const mockOracleContract = await deployments.get("MockOracle");
        mockOracle = await ethers.getContractAt(mockOracleContract.abi, mockOracleContract.address);

        await hre.run("fund-link", { contract: offchainParkingDataResponse.address, linkaddress: linkTokenAddress });
      });

      it("Should successfully make an API request", async () => {
        const transaction = await offchainParkingDataResponse.requestOffchainParkingSpotData();
        const transactionReceipt = await transaction.wait(1);
        const requestId = transactionReceipt.events[0].topics[1];
        console.log("requestId: ", requestId);
        expect(requestId).to.not.be.null;
      });

      it("Should successfully make an API request and get a result", async () => {
        const transaction = await offchainParkingDataResponse.requestOffchainParkingSpotData();
        const transactionReceipt = await transaction.wait(1);
        const requestId = transactionReceipt.events[0].topics[1];
        const callbackValue = "0x0000000000000000000000000000000000000000000000000000000000000000";
        await mockOracle.fulfillOracleRequest(requestId, numToBytes32(callbackValue));
        const parking_spot_location = await offchainParkingDataResponse.parking_spot_location();
        assert.equal(parking_spot_location.toString(), callbackValue.toString());
      });

      it("Our event should successfully fire event on callback", async () => {
        const callbackValue = 777;
        // we setup a promise so we can wait for our callback from the `once` function
        await new Promise(async (resolve, reject) => {
          // setup listener for our event
          offchainParkingDataResponse.once("DataFullfilled", async () => {
            console.log("DataFullfilled event fired!");
            const parking_spot_location = await offchainParkingDataResponse.parking_spot_location();
            // assert throws an error if it fails, so we need to wrap
            // it in a try/catch so that the promise returns event
            // if it fails.
            try {
              assert.equal(parking_spot_location.toString(), callbackValue.toString());
              resolve();
            } catch (e) {
              reject(e);
            }
          });
          const transaction = await offchainParkingDataResponse.requestOffchainParkingSpotData();
          const transactionReceipt = await transaction.wait(1);
          const requestId = transactionReceipt.events[0].topics[1];
          await mockOracle.fulfillOracleRequest(requestId, numToBytes32(callbackValue));
        });
      });
    });
