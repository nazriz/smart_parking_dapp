const { assert, expect } = require("chai");
const { network, deployments, ethers } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");
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
        const transaction = await offchainParkingDataResponse.fakeFulfillBytes();
        const transactionReceipt = await transaction.wait(1);
        // const requestId = transactionReceipt.events[0].topics[1];
        // co-ords of "88.8888, 88.8888"
        const callbackValue = "0x38382e383838382c2038382e3838383800000000000000000000000000000000";
        // await mockOracle.fulfillOracleRequest(requestId, numToBytes32(callbackValue));
        const parking_spot_location = await offchainParkingDataResponse.parking_spot_location();
        assert.equal(parking_spot_location.toString(), callbackValue.toString());
      });

      it("Should map the caller address to the bytes value", async () => {
        const [addr1] = await ethers.getSigners();
        await offchainParkingDataResponse.connect(addr1).fakeFulfillBytes();
        const parking_spot_location = await offchainParkingDataResponse.connect(addr1).parking_spot_location();
        const ownerCheck = await offchainParkingDataResponse.parkingSpotLocationOwner(addr1.address);

        console.log(parking_spot_location);
        console.log(ownerCheck);
        assert.equal(parking_spot_location.toString(), ownerCheck.toString());
      });
    });
