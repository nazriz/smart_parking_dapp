//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

interface ParkingSpotToken {
    function ownerOf(uint) external view returns (address);
}


/// @title ParkingSpotAttributes
/// @author XXXXX XXXXXX.
/// @notice Allows for setting various designated attributes to a parking spot token
contract ParkingSpotAttributes {


    ///@param tokenId id of parking spot available is availability
    event ParkingSpotAvailable(uint256 tokenId, bool available);
    ///@param tokenId id of parking spot inUse toggled as true if parking spot session active
    event ParkingSpotInUse(uint256 tokenId, bool inUse);
    ///@param tokenId id of parking spot available startHour/EndHour 0 - 23, startMinute/endMinute 0 - 59
    event ParkingSpotPermittedTime(uint256 tokenId, uint8 startHour, uint8 startMinute, uint8 endHour, uint8 endMinute);
    ///@param tokenId id of parking spot pricePerHour amount in USD. e.g. 5.5
    event ParkingSpotPricePerHour(uint256 tokenId, uint256 pricePerHour);

///@dev used for holding times in storage, referred to during conversions
///@dev initilise with all values to zero
struct availabilityTimes {
    uint8 startHour;
    uint8 startMinute; 
    uint8 endHour; 
    uint8 endMinute;
}


mapping(uint => bool) public spot_available;
mapping(uint=> availabilityTimes) public permittedParkingTime;
mapping(uint=> uint8[2]) public parkingSpotTimeZone;
mapping(uint256=>bool) public spotInUse;
mapping(uint256=>uint256) public pricePerHour;

// Interface address is for local network, must be updated for network deployed to.
ParkingSpotToken constant pst = ParkingSpotToken(0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9);
//goerli:
// ParkingSpotToken constant pst = ParkingSpotToken(0x7380e28aB1F6ED032671b085390194F07aBC2606);


///@dev returns address of token operator
///@param _parking_spot_id the id of the token
function isApprovedOrOwner(uint _parking_spot_id) internal view returns (bool) {
        return pst.ownerOf(_parking_spot_id) == msg.sender;
    }

///@dev Allows the true owner of the parking spot to 
///@dev toggle the availability of the parking spot. 
///@dev true owner is verified against parkingSpotOwners mapping in ParkingSpotToken Contract
///@param _parking_spot_id the id of the token, availability is bool
function setSpotAvailability(uint _parking_spot_id, bool _availability) external {
    require(isApprovedOrOwner(_parking_spot_id), "Not approved to update parking spot Availability"); 
    spot_available[_parking_spot_id] = _availability;
    spotInUse[_parking_spot_id] = false;
    emit ParkingSpotAvailable(_parking_spot_id, _availability);
}



///@dev Allows the true owner of the parking spot to 
///@dev set the  the times in which the parking spot can be requested for use by user
///@dev true owner is verified against parkingSpotOwners mapping in ParkingSpotToken Contract
///@param _parking_spot_id the id of the token, startHour/EndHour 0 - 23, startMinute/endMinute 0 - 59
function setSpotPermittedParkingTime(uint _parking_spot_id, uint8 _start_hour, uint8 _start_minute, uint8 _end_hour, uint8 _end_minute) external {
    require(_start_hour <= 23, "Start hour must be between 0 and 23");
    require(_start_minute <= 59, "Start minute must be between 0 and 59");
    require(_end_hour <= 23, "End hour must be between 0 and 23");
    require(_end_minute <= 59, "End minute must be between 0 and 59");

    require(isApprovedOrOwner(_parking_spot_id), "Not approved to update parking spot availability times");
    permittedParkingTime[_parking_spot_id] = availabilityTimes(_start_hour, _start_minute, _end_hour, _end_minute);
    emit ParkingSpotPermittedTime( _parking_spot_id,  _start_hour,  _start_minute,  _end_hour,  _end_minute);
}


///@dev Allows the true owner of the parking spot to 
///@dev set the  the timezone in which the parking spot operates.
///@dev true owner is verified against parkingSpotOwners mapping in ParkingSpotToken Contract
///@param _parking_spot_id the id of the token, _isNegative 0 for no, 1 for yes. Denotes whether or not 
///@param the timezone is + or - GMT. _timezone is GMT timezone value * 3600, e.g. GMT 10:00 = 36000
function setParkingSpotTimezone(uint _parking_spot_id, uint8 _isNegative, uint8 _timezone) external {
    require(_timezone <= 14 && _isNegative == 0 || _timezone <= 11 && _isNegative == 1 , "Please input a valid timezone");
    parkingSpotTimeZone[_parking_spot_id] = [_isNegative, _timezone];
}

function setSpotInUse(uint _tokenId, bool _inUse) external {

    spotInUse[_tokenId] = _inUse;
    emit ParkingSpotInUse(_tokenId, _inUse);
}


///@dev Allows the true owner of the parking spot to 
///@dev set the  the timezone in which the parking spot operates.
///@dev true owner is verified against parkingSpotOwners mapping in ParkingSpotToken Contract
///@param _parking_spot_id the id of the token, _isNegative 0 for no, 1 for yes. Denotes whether or not 
///@param the timezone is + or - GMT. _timezone is GMT timezone value * 3600, e.g. GMT 10:00 = 36000
function setPricePerHour (uint256 _tokenId, uint256 _pricePerHour) public {
    pricePerHour[_tokenId] = _pricePerHour;
    emit ParkingSpotPricePerHour(_tokenId, _pricePerHour);

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
function checkParkingSpotTimezone(uint _parking_spot_id) public view returns (uint8[2] memory) {
    return parkingSpotTimeZone[_parking_spot_id];
}

}
