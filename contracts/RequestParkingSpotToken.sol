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

    function checkRequestTimeAgainstPermittedTime(uint _tokenId) internal returns (uint256, uint256) {
        (uint8 permittedStartHour, uint8 permittedStartMinute) = psa.checkSpotPermittedParkingStartTime(_tokenId);
        (uint8 permittedEndHour, uint8 permittedEndMinute) = psa.checkSpotPermittedParkingEndTime(_tokenId);

        uint permittedStartTimeUnix = genericTimeFrameToCurrentUnixTime(permittedStartHour, permittedStartMinute);
        uint permittedEndTimeUnix = genericTimeFrameToCurrentUnixTime(permittedEndHour, permittedEndMinute);
        (permittedEndTimeUnix, permittedEndTimeUnix) = accountForTimezone(permittedStartTimeUnix, permittedEndTimeUnix, _tokenId);
        return (permittedStartTimeUnix, permittedEndTimeUnix);

    }

    function accountForTimezone(uint _start_time, uint _end_time, uint _tokenId) internal returns (uint256, uint256) {
        int256 timezone = int256(int8(psa.checkParkingSpotTimezone(_tokenId)));

        if (timezone > 12) {
            timezone = timezone - 12;
            timezone * -1;
        }

        int256 offset = timezone * 3600;

      int256 _start_time_with_offset = int256(_start_time) + offset;
      int256 _end_time_with_offset = int256(_end_time) + offset;

        _start_time = uint256(_start_time_with_offset);
        _end_time = uint256(_end_time_with_offset);

        return (_start_time, _end_time);

    }

    function requestParkingSpotToken(uint256 _tokenId) public {
        // require(_requestStartTime > );
        (uint parkingSpotStartTime, uint parkingSpotEndTime) = checkAndConvertAvailabilityTime(_tokenId);
        uint256 currentTimeUnix = block.timestamp;

        require(depositors[msg.sender] >= 1000000000000000000, "Must deposit at least 1 Eth");
        require(psa.checkSpotAvailability(_tokenId) == true, "Parking spot is unavailable!");
        require(block.timestamp > parkingSpotStartTime && block.timestamp < parkingSpotEndTime , "Parking spot unavailable at this time!");

        address currentOwner;
        currentOwner = pst.ownerOf(_tokenId);
        pst.safeTransferFrom(currentOwner, msg.sender, _tokenId);

    }

}

