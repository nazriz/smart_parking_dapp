//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract GenericLargeResponse is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    // variable bytes(arbitrary-length raw byte data) returned in a single oracle response
    bytes public data;
    bytes32 public parking_spot_location;
    address private parkingSpotRequesterAddr;

    bytes32 private jobId;
    uint256 private fee;

    constructor() ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x01BE23585060835E02B77ef475b0Cc51aA1e0709);
        setChainlinkOracle(0xf98Cd24CF1f864DF4942165569Fc0114f866067d);
        jobId = "ee2f53a42c624b699bb0a3a381a9ff7f";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    mapping(address=>bytes32[]) public parkingSpotLocationOwnerArray;
    mapping(address=>bytes32) public parkingSpotLocationOwner;


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

    event RequestFulfilled(bytes32 indexed requestId, bytes indexed data);

  
    function fulfillBytes(bytes32 requestId, bytes memory bytesData) public recordChainlinkFulfillment(requestId) {
        emit RequestFulfilled(requestId, bytesData);
        data = bytesData;
        parking_spot_location = bytes32(data);
        parkingSpotLocationOwner[parkingSpotRequesterAddr] = bytes32(data);
        parkingSpotLocationOwnerArray[parkingSpotRequesterAddr].push(bytes32(data));


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


