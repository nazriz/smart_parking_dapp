//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

interface ParkingSpotToken {
    function ownerOf(uint) external view returns (address);
}


contract ParkingSpotAttributes {

struct availabilityTimes {
    uint8 startHour;
    uint8 startMinute; 
    uint8 endHour; 
    uint8 endMinute;
}

mapping(uint => bool) public spot_available;
mapping(uint=> availabilityTimes) public permittedParkingTime;
mapping(uint=> uint8) public parkingSpotTimeZone;



// Interface address is for local network, must be updated for network deployed to.
ParkingSpotToken constant pst = ParkingSpotToken(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9);

function isApprovedOrOwner(uint _parking_spot_id) internal view returns (bool) {
        return pst.ownerOf(_parking_spot_id) == msg.sender;
    }

function setSpotAvailability(uint _parking_spot_id, bool _availability) external {
    require(isApprovedOrOwner(_parking_spot_id), "Not approved to update parking spot Availability"); 
    spot_available[_parking_spot_id] = _availability;
}

function setSpotPermittedParkingTime(uint _parking_spot_id, uint8 _start_hour, uint8 _start_minute, uint8 _end_hour, uint8 _end_minute) external {
    require(_start_hour <= 23, "Start hour must be between 0 and 23");
    require(_start_minute <= 59, "Start minute must be between 0 and 59");
    require(_end_hour <= 23, "End hour must be between 0 and 23");
    require(_end_minute <= 59, "End minute must be between 0 and 59");

    require(isApprovedOrOwner(_parking_spot_id), "Not approved to update parking spot availability times");
    permittedParkingTime[_parking_spot_id] = availabilityTimes(_start_hour, _start_minute, _end_hour, _end_minute);
}

function setParkingSpotTimezone(uint _parking_spot_id, uint8 _timezone) external {
    require(_timezone <= 23, "Timezone must be between 0 and 23");
    parkingSpotTimeZone[_parking_spot_id] = _timezone;
}

function checkSpotAvailability(uint _parking_spot_id) public view returns (bool) {
    return spot_available[_parking_spot_id];
}

function checkSpotPermittedParkingStartTime(uint _parking_spot_id) public view returns (uint8, uint8) {
    availabilityTimes storage _attr = permittedParkingTime[_parking_spot_id];
    return (_attr.startHour, _attr.startMinute); 
}

function checkSpotPermittedParkingEndTime(uint _parking_spot_id) public view returns (uint8, uint8) {
    availabilityTimes storage _attr = permittedParkingTime[_parking_spot_id];
    return (_attr.endHour, _attr.endMinute); 
}
}