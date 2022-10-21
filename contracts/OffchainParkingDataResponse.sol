//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title OffChainParkingDataResponse
/// @author Chainlink Labs. Modified by Nazim Rizvic.
/// @notice Pulls data from a trusted database, and brings on-chain using (local) chainlink node
contract OffchainParkingDataResponse is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    // variable bytes(arbitrary-length raw byte data) returned in a single oracle response
    bytes public data;
    bytes32 public parking_spot_location;
    address private parkingSpotRequesterAddr;

    bytes32 private jobId;
    uint256 private fee;

    constructor(address _oracle, bytes32 _jobId, uint256 _fee, address _link) ConfirmedOwner(msg.sender) {
 
        setChainlinkToken(_link);
        setChainlinkOracle(_oracle);
        jobId = _jobId;
        fee = _fee;
    }

    mapping(address=>bytes32[]) public parkingSpotLocationOwnerArray;
    mapping(address=>bytes32) public parkingSpotLocationOwner;

    ///@param requestor address who made the call location parking spot bytes
    event ParkingSpotLocationOnchain(address requestor, bytes32 location);

    event RequestFulfilled(bytes32 indexed requestId, bytes indexed data);


    ///@dev call to bring off-chain parking spot bytes on-chain. Must provide appropriate
    ///@dev public API that can be queried using the format specified in api_url var,
    ///@dev with address taken as query parameter
    function requestOffchainParkingSpotData() public {
        parkingSpotRequesterAddr = msg.sender;
        string memory sender_address = Strings.toHexString(uint160(msg.sender), 20);
        Chainlink.Request memory req = buildChainlinkRequest(jobId, address(this), this.fulfillBytes.selector);
        string memory api_url = "https://yfkocaqzu8.execute-api.us-east-1.amazonaws.com/test/register?address=";
        string memory url = string.concat(api_url,sender_address);
        req.add("get", url );
        req.add("path","location"); // Chainlink nodes 1.0.0 and later support this format
        sendChainlinkRequest(req, fee);
    }

  

  
    function fulfillBytes(bytes32 requestId, bytes memory bytesData) public recordChainlinkFulfillment(requestId) {
        emit RequestFulfilled(requestId, bytesData);
        data = bytesData;
        parking_spot_location = bytes32(data);
        parkingSpotLocationOwner[parkingSpotRequesterAddr] = bytes32(data);
        parkingSpotLocationOwnerArray[parkingSpotRequesterAddr].push(bytes32(data));
        emit ParkingSpotLocationOnchain(parkingSpotRequesterAddr, parking_spot_location);
    }

    function fakeFulfillBytes() public {

        // emit RequestFulfilled(requestId, bytesData);
        data = "88.8888, 88.8888";
        parking_spot_location = bytes32(data);
        parkingSpotLocationOwner[msg.sender] = bytes32(data);
        parkingSpotLocationOwnerArray[msg.sender].push(bytes32(data));
        emit ParkingSpotLocationOnchain(msg.sender, parking_spot_location);


    }


    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), 'Unable to transfer');
    }


    function checkParkingSpotLocationOwner(address _address) public view returns ( bytes32) {
        return parkingSpotLocationOwner[_address];
    }

       function checkParkingSpotLocationOwnerArray(address _address, uint16 _index) public view returns ( bytes32) {
        return parkingSpotLocationOwnerArray[_address][_index];
    }

}


