const { assert, expect } = require("chai");
const { network, deployments, ethers } = require("hardhat");
const { developmentChains } = require("../../helper-hardhat-config");
const { numToBytes32 } = require("@chainlink/test-helpers/dist/src/helpers");

!developmentChains.includes(network.name)
  ? describe.skip
  : describe("ParkingSpotToken Unit Tests", async function () {
      let offchainParkingDataResponse, parkingSpotToken, linkToken, mockOracle;

      beforeEach(async () => {
        const chainId = network.config.chainId;
        await deployments.fixture(["mocks", "api", "token", "exposedToken"]);
        const linkTokenContract = await deployments.get("LinkToken");
        linkToken = await ethers.getContractAt(linkTokenContract.abi, linkTokenContract.address);
        linkTokenAddress = linkToken.address;
        additionalMessage = ` --linkaddress  ${linkTokenAddress}`;
        const offchainParkingDataResponseContract = await deployments.get("OffchainParkingDataResponse");
        offchainParkingDataResponse = await ethers.getContractAt(
          offchainParkingDataResponseContract.abi,
          offchainParkingDataResponseContract.address
        );
        const parkingSpotTokenContract = await deployments.get("ParkingSpotToken");
        parkingSpotToken = await ethers.getContractAt(parkingSpotTokenContract.abi, parkingSpotTokenContract.address);
        // [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();
        const mockOracleContract = await deployments.get("MockOracle");
        mockOracle = await ethers.getContractAt(mockOracleContract.abi, mockOracleContract.address);

        await hre.run("fund-link", { contract: offchainParkingDataResponse.address, linkaddress: linkTokenAddress });
      });

      describe("Check OwnerOf token", function () {
        it("Should return the correct owner of the minted parking token", async () => {
          const [addr1] = await ethers.getSigners();
          await offchainParkingDataResponse.connect(addr1).fakeFulfillBytes();
          const parking_spot_location = await offchainParkingDataResponse.connect(addr1).parking_spot_location();
          console.log(parking_spot_location);

          // await parkingSpotToken.mintParkingSpot(addr1.address, 0);
          // expect(await parkingSpotToken.ownerOf(1)).to.equal(addr1.address);
        });
      });

      it("Should mint a parking spot token", async () => {
        const [owner] = await ethers.getSigners();
        // console.log(owner);

        await offchainParkingDataResponse.connect(owner).fakeFulfillBytes();
        await parkingSpotToken.mintParkingSpot(owner, 0);
        // tokenURI = await parkingSpotToken.tokenURI(0);
        // console.log(tokenURI);
        // expect(tokenURI).to.equal("test");
      });

      //This will not work, as it's testing an internal function, need to use a workaround
      //   it("Should retrieve latitude and longitude from the OffchainParkingDataResponse contract", async () => {
      //     //Check at index 0,
      //     const transaction = await parkingSpotToken.retrieveLatLongBytes(0);
      //     const testLatLongBytes = "0x38382e383838382c2038382e3838383800000000000000000000000000000000";
      //     console.log(transaction);

      //     assert.equal(transaction.toString(), testLatLongBytes.toString());
      //   });
    });
