//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./BokkyPooBahsDateTimeContract.sol";

interface ParkingSpotAttributes {
    function checkSpotAvailability(uint) external view returns (bool);
    function checkSpotPermittedParkingStartTime(uint ) external view returns (uint8, uint8);
    function checkSpotPermittedParkingEndTime(uint ) external view returns (uint8, uint8);
    function checkParkingSpotTimezone(uint ) external view returns (uint8);


}

interface ParkingSpotToken {
    function ownerOf(uint256) external returns (address);
    function safeTransferFrom(address,address,uint256) external;

}

contract RequestParkingSpotToken {
using BokkyPooBahsDateTimeLibrary for *;

    struct DateTime {
        uint256 Year;
        uint256 Month; 
        uint256 Day;
        uint256 Hour; 
        uint256 Minute;
        uint256 Second;
    }

    DateTime current = DateTime(0,0,0,0,0,0);

    mapping(address=>uint256) public depositors;

    ParkingSpotAttributes constant psa = ParkingSpotAttributes(0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9);
    ParkingSpotToken constant pst = ParkingSpotToken(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9);



    // Payable address can receive Ether
    address payable public owner;

    // Payable constructor can receive Ether
    constructor() payable {
        owner = payable(msg.sender);
    }

    function deposit() public payable {
        depositors[msg.sender] += msg.value;
    }

    function withdraw(uint256 _amount) public {
        require(_amount <= depositors[msg.sender], "Not enough ETH deposited");
        depositors[msg.sender] -= _amount;
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Failed to send Ether");

    }
    
    function getCurrentDateTime () internal {
        (current.Year, current.Month, current.Day, current.Hour, current.Minute, current.Second) = BokkyPooBahsDateTimeLibrary.timestampToDateTime(block.timestamp);
    }

    function genericTimeFrameToCurrentUnixTime(uint8 _hour, uint8 _minute) internal returns (uint) {
        getCurrentDateTime();
       return BokkyPooBahsDateTimeLibrary.timestampFromDateTime(current.Year, current.Month, current.Day, _hour, _minute, 0);
    }

    function retrievePermittedParkingTimes(uint _tokenId) internal returns (uint256, uint256) {
        (uint8 permittedStartHour, uint8 permittedStartMinute) = psa.checkSpotPermittedParkingStartTime(_tokenId);
        (uint8 permittedEndHour, uint8 permittedEndMinute) = psa.checkSpotPermittedParkingEndTime(_tokenId);

        uint permittedStartTimeUnix = genericTimeFrameToCurrentUnixTime(permittedStartHour, permittedStartMinute);
        uint permittedEndTimeUnix = genericTimeFrameToCurrentUnixTime(permittedEndHour, permittedEndMinute);
        permittedStartTimeUnix = accountForTimezone(permittedStartTimeUnix, _tokenId);
        permittedEndTimeUnix  =  accountForTimezone(permittedEndTimeUnix, _tokenId);

        return (permittedStartTimeUnix, permittedEndTimeUnix);

    }

    function accountForTimezone(uint _unixTime, uint _tokenId) internal returns (uint256) {
        int256 timezone = int256(int8(psa.checkParkingSpotTimezone(_tokenId)));

        if (timezone > 12) {
            timezone = timezone - 12;
            timezone * -1;
        }

        int256 offset = timezone * 3600;

      int256 _unixTimeWithOffset = int256(_unixTime) + offset;
    //   int256 _end_time_with_offset = int256(_end_time) + offset;

        _unixTime = uint256(_unixTimeWithOffset);
        // _end_time = uint256(_end_time_with_offset);

        return _unixTime;

    }

    function requestParkingSpotToken(uint256 _tokenId, uint8 _requestedStartHour, uint8 _requestedStartMinute, uint8 _requestedEndHour, uint8 _requestedEndMinute) public {
        require(_requestedStartHour <= 23, "Start hour must be between 0 and 23");
        require(_requestedStartMinute <= 59, "Start minute must be between 0 and 59");
        require(_requestedEndHour <= 23, "End hour must be between 0 and 23");
        require(_requestedEndMinute <= 59, "End minute must be between 0 and 59");

        (uint parkingSpotStartTime, uint parkingSpotEndTime) = retrievePermittedParkingTimes(_tokenId);
        uint256 requestedStartTimeUnix = accountForTimezone(genericTimeFrameToCurrentUnixTime(_requestedStartHour,_requestedStartMinute), _tokenId);
        uint256 requestedEndTimeUnix = accountForTimezone(genericTimeFrameToCurrentUnixTime(_requestedEndHour,_requestedEndMinute), _tokenId);
        require(requestedStartTimeUnix > block.timestamp, "Can't request parking spot in the past!");
        require(depositors[msg.sender] >= 1000000000000000000, "Must deposit at least 1 Eth");
        require(psa.checkSpotAvailability(_tokenId) == true, "Parking spot is unavailable!");
        require(requestedStartTimeUnix > parkingSpotStartTime && requestedEndTimeUnix < parkingSpotEndTime , "Parking spot unavailable at this time!");

        address currentOwner;
        currentOwner = pst.ownerOf(_tokenId);
        pst.safeTransferFrom(currentOwner, msg.sender, _tokenId);

    }

}

