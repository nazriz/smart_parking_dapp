const { assert, expect } = require("chai");
const { network, deployments, ethers } = require("hardhat");
// const { developmentChains } = require("../helper-hardhat-config");

describe("RequestParkingSpot Unit Tests", async function () {
  let offchain, linkToken, mockOracle, attributes, token, requestSpot;
  let requestContractAddress;

  beforeEach(async () => {
    await deployments.fixture(["mocks", "api", "token", "attributes", "request"]);
    // const linkTokenContract = await deployments.get("LinkToken");

    const offchainParkingDataResponseContract = await deployments.get("OffchainParkingDataResponse");
    offchain = await ethers.getContractAt(
      offchainParkingDataResponseContract.abi,
      offchainParkingDataResponseContract.address
    );

    const parkingSpotTokenContract = await deployments.get("ParkingSpotToken");
    token = await ethers.getContractAt(parkingSpotTokenContract.abi, parkingSpotTokenContract.address);

    const parkingSpotAttributesContract = await deployments.get("ParkingSpotAttributes");
    attributes = await ethers.getContractAt(parkingSpotAttributesContract.abi, parkingSpotAttributesContract.address);

    const requestParkingSpotContract = await deployments.get("RequestParkingSpotToken");
    requestSpot = await ethers.getContractAt(requestParkingSpotContract.abi, requestParkingSpotContract.address);

    requestContractAddress = requestParkingSpotContract.address;

    // Mint Token from addr1

    // console.log("depositing 100 eth...");
    // await requestSpot.connect(addr2).deposit({ value: ethers.utils.parseUnits("100", "ether") });
    // await requestSpot.connect(addr3).deposit({ value: ethers.utils.parseUnits("100", "ether") });
    // await requestSpot.connect(addr4).deposit({ value: ethers.utils.parseUnits("100", "ether") });
  });

  describe("Request offchain data ", function () {
    it("Should fulfill bytes", async () => {
      const [addr1, addr2, addr3, addr4, addr5, addr6, addr7, addr8, addr9, addr10, addr11] = await ethers.getSigners();

      let requestContractAddress = requestSpot.address;

      await offchain.connect(addr1).fakeFulfillBytes();
      await token.mintParkingSpot(addr1.address, 0);
      await attributes.setSpotAvailability(1, 1);
      await attributes.setPricePerHour(1, 5);
      await attributes.connect(addr1).setSpotPermittedParkingTime(1, 09, 00, 23, 00);
      await token.connect(addr1).setApprovalForRequestContract(1, requestContractAddress, true);
      await attributes.setParkingSpotTimezone(1, 1, 11);

      // for (i = 1; i < 26; i++) {
      //   await offchain.connect(addr1).fakeFulfillBytes();
      //   await token.mintParkingSpot(addr1.address, i - 1);
      //   await attributes.setSpotAvailability(i, 1);
      //   await attributes.setPricePerHour(i, 5);
      //   await attributes.connect(addr1).setSpotPermittedParkingTime(i, 09, 00, 23, 00);
      //   await token.connect(addr1).setApprovalForRequestContract(i, requestContractAddress, true);
      //   await attributes.setParkingSpotTimezone(i, 1, 11);
      // }

      await requestSpot.connect(addr2).deposit({ value: ethers.utils.parseUnits("100", "ether") });
      await requestSpot.connect(addr3).deposit({ value: ethers.utils.parseUnits("100", "ether") });
      // await requestSpot.connect(addr4).deposit({ value: ethers.utils.parseUnits("100", "ether") });
      // await requestSpot.connect(addr5).deposit({ value: ethers.utils.parseUnits("100", "ether") });
      // await requestSpot.connect(addr6).deposit({ value: ethers.utils.parseUnits("100", "ether") });
      // await requestSpot.connect(addr7).deposit({ value: ethers.utils.parseUnits("100", "ether") });
      // await requestSpot.connect(addr8).deposit({ value: ethers.utils.parseUnits("100", "ether") });
      // await requestSpot.connect(addr9).deposit({ value: ethers.utils.parseUnits("100", "ether") });
      // await requestSpot.connect(addr10).deposit({ value: ethers.utils.parseUnits("100", "ether") });
      // await requestSpot.connect(addr11).deposit({ value: ethers.utils.parseUnits("100", "ether") });

      await requestSpot.connect(addr2).reserveParkingSpotToken(1, 18, 00, 18, 59);

      // for (i = 1; i < 26; i++) {
      //   await requestSpot.connect(addr2).reserveParkingSpotToken(i, 12, 00, 12, 59);
      //   await requestSpot.connect(addr3).reserveParkingSpotToken(i, 13, 00, 13, 59);
      //   await requestSpot.connect(addr4).reserveParkingSpotToken(i, 14, 00, 14, 59);
      //   await requestSpot.connect(addr5).reserveParkingSpotToken(i, 15, 00, 15, 30);
      //   await requestSpot.connect(addr6).reserveParkingSpotToken(i, 16, 00, 16, 59);
      //   await requestSpot.connect(addr8).reserveParkingSpotToken(i, 17, 30, 17, 59);
      //   await requestSpot.connect(addr9).reserveParkingSpotToken(i, 18, 00, 18, 29);
      //   await requestSpot.connect(addr9).reserveParkingSpotToken(i, 19, 00, 19, 59);
      //   await requestSpot.connect(addr9).reserveParkingSpotToken(i, 20, 00, 20, 59);

      //   // await ethers.provider.send("evm_mine");
      // }

      await requestSpot.distributeParkingSpots();

      await ethers.provider.send("evm_mine", [1666167444]);

      // await requestSpot.distributeParkingSpots();

      // await ethers.provider.send("evm_mine", [1666148401]);

      // await requestSpot.distributeParkingSpots();

      // await ethers.provider.send("evm_mine", [1666152001]);

      // await requestSpot.distributeParkingSpots();

      // await ethers.provider.send("evm_mine", [1666155601]);

      // await requestSpot.distributeParkingSpots();

      // await ethers.provider.send("evm_mine", [1666161001]);

      // await requestSpot.distributeParkingSpots();

      // await ethers.provider.send("evm_mine", [1666162801]);

      // await requestSpot.distributeParkingSpots();

      // await ethers.provider.send("evm_mine", [1666166401]);

      // await requestSpot.distributeParkingSpots();

      // await ethers.provider.send("evm_mine", [1666170001]);

      // await requestSpot.distributeParkingSpots();
    });
  });
});
