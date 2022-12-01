///SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./BokkyPooBahsDateTimeContract.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


interface ParkingSpotAttributes {
    function checkSpotAvailability(uint) external view returns (bool);
    function checkSpotPermittedParkingStartTime(uint ) external view returns (uint8, uint8);
    function checkSpotPermittedParkingEndTime(uint ) external view returns (uint8, uint8);
    function checkParkingSpotTimezone(uint ) external view returns (uint8[2] memory);
    function spotInUse(uint) external view returns (bool);
    function setSpotInUse(uint, bool ) external;
    function pricePerHour(uint) external view returns (uint);

}

interface ParkingSpotToken {
    function ownerOf(uint256) external returns (address);
    function safeTransferFrom(address,address,uint256) external;
    function safeTransferFromWithOwnerApprovals(address,address,uint256) external;
    function _parkingSpotOwners(uint) external view returns (address);
    function paymentAddress(uint) external view returns (address);
    function getTokenCount() external view returns (uint256);
 
}


//// @title RequestParkingSpotToken
//// @author XXXXX XXXXXX
//// @notice Allows for users to reseve parking spot tokens. Facilitates
//// @notice  the movement of tokens between users using off-chain automation
contract RequestParkingSpotToken {
using BokkyPooBahsDateTimeLibrary for *;

////@param user address of depositor, amount amount in ETH
event EthDeposit(address user, uint256 amount);
////@param user address of withdrawal, amount amount in ETH
event EthWithdraw(address user, uint256 amount);
////@param tokenId the id of the parking spot token, cost the
////@param cost of the session in gwei/second * session duration in seconds
event EstimatedSessionCost(uint256 tokenId, uint256 cost);
////@param tokenId id of parking spot available startHour/EndHour 0 - 23, startMinute/endMinute 0 - 59
event ActiveParkingSesion(uint256 tokenId, uint8 requestedStartHour, uint8 requestedStartMinute, uint8 requestedEndHour, uint8 requestedEndMinute);
////@param tokenId the id of the parking spot token,
event EndActiveParkingSesion(uint256 tokenId);


////@dev used for holding times temporarily between 
////@dev time converesions initilise with all values to zero
    struct DateTime {
        uint256 Year;
        uint256 Month; 
        uint256 Day;
        uint256 Hour; 
        uint256 Minute;
        uint256 Second;
    }

////@dev used as a data structure for holding reserved 
////@dev parking times, in an array of TimeSlots
    struct TimeSlots {
        address walletAddress;
        uint256 startTime;
        uint256 endTime; 
    }


    /// Initilaise DateTime once, then use as required
    DateTime current = DateTime(0,0,0,0,0,0);

    mapping(address=>uint256) public depositors;
    mapping(uint256=> address) public currentParkingSpotOwner;
    mapping(uint256=>uint256[2]) public requestedParkingTimes;
    mapping(address=>bool) public sessionInProgress;
    mapping(uint256=>uint256) public sessionCost;
    mapping(uint256=>TimeSlots) availableSlots;
    uint256[] public activeSessions;
    mapping(uint256=>TimeSlots[]) public reservedParkingTimes;
    mapping(uint256=>TimeSlots[]) public tempReservedParkingTimes;
    mapping(address=>bytes32) public hashedVehicleRegistration;
    mapping(uint256=>address) public spotLastUsedBy;


    AggregatorV3Interface internal ethUSDpriceFeed;

    /// ///localhost:
    ParkingSpotAttributes constant psa = ParkingSpotAttributes(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707);
    ParkingSpotToken constant pst = ParkingSpotToken(0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9);
    /// Goerli:
    /// ParkingSpotAttributes constant psa = ParkingSpotAttributes(0x0A0Bbb42636AB8C3516882519ADD39DF56dCc5A5);
    /// ParkingSpotToken constant pst = ParkingSpotToken(0x7380e28aB1F6ED032671b085390194F07aBC2606);

    /// Payable address can receive Ether
    address payable public owner;

    constructor() payable {
        owner = payable(msg.sender);
        ///localhost
        ethUSDpriceFeed = AggregatorV3Interface(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
        ///goerli
        /// ethUSDpriceFeed = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e);
    }


////@dev Allows for deposits in ether to the contract
    function deposit() public payable {
        depositors[msg.sender] += msg.value;
        emit EthDeposit(msg.sender, msg.value);
    }

////@dev Allows for ether withdrawals
////@param _amount the amount to withdraw in ether
    function withdraw(uint256 _amount) public {
        require(_amount <= depositors[msg.sender], "Not enough ETH deposited");
        depositors[msg.sender] -= _amount;
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Failed to send Ether");
        require(sessionInProgress[msg.sender] == false, "You cannot withdraw ETH while parking session in progress. Please wait until the session is completed, or end the session manually!");
        emit EthWithdraw(msg.sender, _amount);

    }
    
////@dev Converts current timestamp in Unix to datetime
////@dev e.g. 1666315186 > 21/10/2022 01:19:46
    function getCurrentDateTime () internal {
        (current.Year, current.Month, current.Day, current.Hour, current.Minute, current.Second) = BokkyPooBahsDateTimeLibrary.timestampToDateTime(block.timestamp);
    }

////@dev Converts arbitrary time to Unix time for the 
////@dev date in which function is called e.g. 10:30 > 1666308646
    function genericTimeFrameToCurrentUnixTime(uint8 _hour, uint8 _minute) internal returns (uint) {
        getCurrentDateTime();
       return BokkyPooBahsDateTimeLibrary.timestampFromDateTime(current.Year, current.Month, current.Day, _hour, _minute, 0);
    }

///@dev Checks permittedParkingTime in ParkingSpotAttributes for the 
///@dev the times specified by true parking spot owner for parking
////@dev spot to be in use, and then converts these times into current
////@dev Unix time. e.g. 09:00 to 17:00 > 1666303200 to 1666332000
////@param _tokenId the id of the parking spot token
    function retrievePermittedParkingTimes(uint _tokenId) internal returns (uint256, uint256) {
        (uint8 permittedStartHour, uint8 permittedStartMinute) = psa.checkSpotPermittedParkingStartTime(_tokenId);
        (uint8 permittedEndHour, uint8 permittedEndMinute) = psa.checkSpotPermittedParkingEndTime(_tokenId);

        uint permittedStartTimeUnix = accountForTimezone(genericTimeFrameToCurrentUnixTime(permittedStartHour, permittedStartMinute), _tokenId);
        uint permittedEndTimeUnix = accountForTimezone(genericTimeFrameToCurrentUnixTime(permittedEndHour, permittedEndMinute), _tokenId);
        return (permittedStartTimeUnix, permittedEndTimeUnix);
    }

    function setIsNegative(bool _isNegative) internal {
        _isNegative = true;
    }

    function setSessionInProgress(address _address, bool _status) internal {
        sessionInProgress[_address] = _status;
    }

////@dev Used after time conversions have occurred, and accounts for
////@dev the timezone of the designated parking spot. Adds or substracts
////@dev in increments of 3600 (1 hour), depending on the timezone value
////@dev present in ParkingSpotAttributes
///@param _unixTime time to be converted, in Unix _tokenId the id of the parking spot token
    function accountForTimezone(uint _unixTime, uint _tokenId) internal returns (uint256) {
        uint8[2] memory timezoneAttributes  = (psa.checkParkingSpotTimezone(_tokenId));    
        uint256 offset = (timezoneAttributes[1] * 3600);
        uint256 newTime;
        if (timezoneAttributes[0] == 1) {
         newTime = (_unixTime - offset);

        } else {
        newTime = (_unixTime + offset);
        }

        return newTime;

    }

////@dev Calculates the cost of a parking session, based 
////@dev  on the dollar/hour price specified in ParkingSpotAttributes
////@dev requires external pricefeed for ETH/USD. 
////@dev Chainlink feed used in current implementation. 
////@dev Converts dollar/hour rate to gwei/second, and then
////@dev multiplies this value by the session duratuon in seconds
///@param  _tokenId the id of the parking spot token, _startTimeUnix the starting time of
///@param  the session in Unix format, _endTimeUnix the end time of the session in Unix format
    function calculateSessionCost(uint256 _tokenId, uint256 _startTimeUnix, uint256 _endTimeUnix) public returns (uint256) {
        uint256 hourlyRateUSD = (psa.pricePerHour(_tokenId) * (10**8));
        int256 ethUSDPrice = getLatestPrice();
        uint256 hourlyRateGwei = (1000000000000000000 / (uint256(ethUSDPrice) / hourlyRateUSD));   
        uint256 gweiBySecond = ((hourlyRateGwei / 3600) / 10**2);

        uint256 duration = (_endTimeUnix - _startTimeUnix);


        emit EstimatedSessionCost(_tokenId, duration * gweiBySecond);

        return duration * gweiBySecond;
    }


////@dev Slots a parking spot reservation into the middle of the storage array
///@param   _tokenId the id of the parking spot token, caller the address of the user
///@param   making the reservation, requestedStartTime/requestedEndTime the start and
///@param   end times of the reservation in Unix format, timeSlotsLength the 
///@param   current length of the storage array, _index the index that the new 
///@param   reservation will be placed into

    function slotInMiddleForOther(uint256 _tokenId, address caller, uint256 requestedStartTime, uint256 requestedEndTime, uint timeSlotsLength, uint _index) internal returns (bool) {
                                delete tempReservedParkingTimes[_tokenId];

                                TimeSlots memory tempTimeSlot;

                                for (uint x = 0; x <= _index; x++) {
                                tempTimeSlot.walletAddress = reservedParkingTimes[_tokenId][x].walletAddress;
                                tempTimeSlot.startTime = reservedParkingTimes[_tokenId][x].startTime;
                                tempTimeSlot.endTime = reservedParkingTimes[_tokenId][x].endTime;

                                tempReservedParkingTimes[_tokenId].push(tempTimeSlot);

                                }                             

                                tempTimeSlot.walletAddress = caller;
                                tempTimeSlot.startTime = requestedStartTime;
                                tempTimeSlot.endTime = requestedEndTime;

                                tempReservedParkingTimes[_tokenId].push(tempTimeSlot);

                                uint j = _index + 1;
                                for (j; j < timeSlotsLength; j++ ) {
                                
                                tempTimeSlot.walletAddress = reservedParkingTimes[_tokenId][j].walletAddress;
                                tempTimeSlot.startTime = reservedParkingTimes[_tokenId][j].startTime;
                                tempTimeSlot.endTime = reservedParkingTimes[_tokenId][j].endTime;
                                tempReservedParkingTimes[_tokenId].push(tempTimeSlot);

                                 }

                                reservedParkingTimes[_tokenId] = tempReservedParkingTimes[_tokenId];
                                return true;

    }

////@dev Slots a parking spot reservation into the middle of the storage array
///@param   _tokenId the id of the parking spot token, caller the address of the user
///@param   making the reservation, requestedStartTime/requestedEndTime the start and
///@param   end times of the reservation in Unix format, timeSlotsLength the 
///@param   current length of the storage array, _index the index that the new 
///@param   reservation will be placed into

    function slotInMiddleForZero(uint256 _tokenId, address caller, uint256 requestedStartTime, uint256 requestedEndTime, uint timeSlotsLength) internal returns (bool) {
                                delete tempReservedParkingTimes[_tokenId];

                                TimeSlots memory tempTimeSlot;
                                 
                                tempTimeSlot.walletAddress = reservedParkingTimes[_tokenId][0].walletAddress;
                                tempTimeSlot.startTime = reservedParkingTimes[_tokenId][0].startTime;
                                tempTimeSlot.endTime = reservedParkingTimes[_tokenId][0].endTime;

                                tempReservedParkingTimes[_tokenId].push(tempTimeSlot);

                                tempTimeSlot.walletAddress = caller;
                                tempTimeSlot.startTime = requestedStartTime;
                                tempTimeSlot.endTime = requestedEndTime;

                                tempReservedParkingTimes[_tokenId].push(tempTimeSlot);

                                
                                for (uint j = 1; j < timeSlotsLength; j++ ) {
                                
                                tempTimeSlot.walletAddress = reservedParkingTimes[_tokenId][j].walletAddress;
                                tempTimeSlot.startTime = reservedParkingTimes[_tokenId][j].startTime;
                                tempTimeSlot.endTime = reservedParkingTimes[_tokenId][j].endTime;
                                tempReservedParkingTimes[_tokenId].push(tempTimeSlot);

                                 }

                                reservedParkingTimes[_tokenId] = tempReservedParkingTimes[_tokenId];
                                return true;

    }

////@dev Slots a parking spot reservation into the middle of the storage array
///@param   _tokenId the id of the parking spot token, caller the address of the user
///@param   making the reservation, requestedStartTime/requestedEndTime the start and
///@param   end times of the reservation in Unix format, timeSlotsLength the 
///@param   current length of the storage array, _index the index that the new 
///@param   reservation will be placed into

    function slotTimeSlotinMiddle(uint256 _tokenId, address caller, uint256 requestedStartTime, uint256 requestedEndTime, uint timeSlotsLength) internal returns (bool) {
                uint i = 0;
            for (i; i < timeSlotsLength; i++) {
                    uint overflowCheck = i;
                    overflowCheck++;

                     if (requestedStartTime > reservedParkingTimes[_tokenId][i].endTime) {
                        if (overflowCheck > timeSlotsLength) {

                                TimeSlots memory tempTimeSlot;
                        
                                tempTimeSlot.walletAddress = caller;
                                tempTimeSlot.startTime = requestedStartTime;
                                tempTimeSlot.endTime = requestedEndTime;

                                reservedParkingTimes[_tokenId].push(tempTimeSlot);
                                break;
                        } else {
                            if(requestedEndTime < reservedParkingTimes[_tokenId][overflowCheck].startTime) {
                                if  (i == 0) {
                                 slotInMiddleForZero(_tokenId, caller, requestedStartTime, requestedEndTime, timeSlotsLength);
                                 return true;
                            } else {
                                slotInMiddleForOther(_tokenId, caller, requestedStartTime, requestedEndTime, timeSlotsLength, i);
                                return true;
                            }
                                continue;
                            }

                        }
                        continue;

                 } else {
                    revert("Invalid parking time slot");

                 } 
 
            }

            return true;

     }

////@dev Slots a parking spot reservation to the end of the storage array
////@param   _tokenId the id of the parking spot token, caller the address of the user
////@param   making the reservation, requestedStartTime/requestedEndTime the start and
////@param   end times of the reservation in Unix format
     function addTimeSlotToEnd(uint256 _tokenId, address caller, uint256 requestedStartTime, uint256 requestedEndTime) internal returns (bool) {

        TimeSlots memory tempTimeSlot;

        tempTimeSlot.walletAddress = caller;
        tempTimeSlot.startTime = requestedStartTime;
        tempTimeSlot.endTime = requestedEndTime;
        reservedParkingTimes[_tokenId].push(tempTimeSlot);
        return true;

     }

////@dev Adds a parking spot reservation to the start of the storage array
///@param  _tokenId the id of the parking spot token, caller the address of the user
///@param   making the reservation, requestedStartTime/requestedEndTime the start and
///@param   end times of the reservation in Unix format timeSlotsLength the 
///@param   current length of the storage array,
     function addTimeSlotToStart(uint256 _tokenId, address caller, uint256 requestedStartTime, uint256 requestedEndTime, uint256 timeSlotsLength) internal returns (bool) {

                                delete tempReservedParkingTimes[_tokenId];

                                TimeSlots memory tempTimeSlot;
                                 
                                tempTimeSlot.walletAddress = caller;
                                tempTimeSlot.startTime = requestedStartTime;
                                tempTimeSlot.endTime = requestedEndTime;

                                tempReservedParkingTimes[_tokenId].push(tempTimeSlot);

                                
                                for (uint j = 0; j < timeSlotsLength; j++ ) {
                                
                                tempTimeSlot.walletAddress = reservedParkingTimes[_tokenId][j].walletAddress;
                                tempTimeSlot.startTime = reservedParkingTimes[_tokenId][j].startTime;
                                tempTimeSlot.endTime = reservedParkingTimes[_tokenId][j].endTime;
                                tempReservedParkingTimes[_tokenId].push(tempTimeSlot);

                                 }

                                reservedParkingTimes[_tokenId] = tempReservedParkingTimes[_tokenId];
                                return true;

     }


 
  ////@dev Allows a user to reserve a parking spot, assuming their request
  ////@dev does not revert the transaction by falling outside the allowed params.

////@param  _tokenId the id of the parking spot token, caller the address of the user
////@param   making the reservation,  _requestedStartHour/_requestedEndHour 0 - 23, _requestedStartMinute/_requestedEndMinute 0 - 59
    function reserveParkingSpotToken(uint256 _tokenId, uint8 _requestedStartHour, uint8 _requestedStartMinute, uint8 _requestedEndHour, uint8 _requestedEndMinute) public returns (bool) {
        require(_requestedStartHour <= 23, "Start hour must be between 0 and 23");
        require(_requestedStartMinute <= 59, "Start minute must be between 0 and 59");
        require(_requestedEndHour <= 23, "End hour must be between 0 and 23");
        require(_requestedEndMinute <= 59, "End minute must be between 0 and 59");
        require(depositors[msg.sender] >= 10000000000000000, "Must deposit at least 0.01 Eth");

        (uint256 parkingSpotStartTime, uint256 parkingSpotEndTime) = retrievePermittedParkingTimes(_tokenId);
        uint256 requestedStartTimeUnix = accountForTimezone(genericTimeFrameToCurrentUnixTime(_requestedStartHour,_requestedStartMinute), _tokenId);
        uint256 requestedEndTimeUnix = accountForTimezone(genericTimeFrameToCurrentUnixTime(_requestedEndHour,_requestedEndMinute), _tokenId);

        TimeSlots memory tempTimeSlot ;
        uint timeSlotsLength = reservedParkingTimes[_tokenId].length;
        uint lastIndex;

        if (timeSlotsLength > 1) {
            lastIndex = (timeSlotsLength - 1);
        }

    
        if (timeSlotsLength == 0) {

        tempTimeSlot.walletAddress = msg.sender;
        tempTimeSlot.startTime = requestedStartTimeUnix;
        tempTimeSlot.endTime = requestedEndTimeUnix;
        reservedParkingTimes[_tokenId].push(tempTimeSlot);
            return true;


        } else if (timeSlotsLength == 1) {
            if (requestedStartTimeUnix > reservedParkingTimes[_tokenId][lastIndex].endTime) {
                addTimeSlotToEnd(_tokenId, msg.sender, requestedStartTimeUnix, requestedEndTimeUnix);
                return true;
            }


            if (reservedParkingTimes[_tokenId][0].endTime < requestedStartTimeUnix) {
                tempTimeSlot.walletAddress = msg.sender;
                tempTimeSlot.startTime = requestedStartTimeUnix;
                tempTimeSlot.endTime = requestedEndTimeUnix;
                reservedParkingTimes[_tokenId].push(tempTimeSlot);
            return true;

            } else {
                revert("Time Slot unavailable, please try again");
            }
        } else {
            if (requestedStartTimeUnix > reservedParkingTimes[_tokenId][lastIndex].endTime) {
                addTimeSlotToEnd(_tokenId, msg.sender, requestedStartTimeUnix, requestedEndTimeUnix);
                return true;
            }
            slotTimeSlotinMiddle(_tokenId, msg.sender, requestedStartTimeUnix, requestedEndTimeUnix, timeSlotsLength);
            return true;
        }
    }

///@dev used to interact with Chainlink pricefeed
function getLatestPrice() public view returns (int) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = ethUSDpriceFeed.latestRoundData();
        return price;
    }



///@dev function called by off-chain automaation solution to distrbute
///@dev parking spots between users as the parking spot sessions commence
///@dev and conclude. WARNING: Function does NOT reasonably scale past
///@dev a few dozens parking spots, before becoming practically unusable
///@dev For demonstration purposes only. Use at own risk. 

    function distributeParkingSpots() external {
        uint256 tokenCount = pst.getTokenCount();

        for (uint x = 1; x <= tokenCount; x ++) {
            for (uint y=0; y < reservedParkingTimes[x].length; y++ ) {
                
                /// start of new session
                if (reservedParkingTimes[x][y].startTime < block.timestamp) {

                    if (!(pst.ownerOf(x) == pst._parkingSpotOwners(x))) {
                    endParkingSession(x);

                    if (!(y+1 > reservedParkingTimes[x].length)) {
                    uint timeToNextUser =  (block.timestamp % reservedParkingTimes[x][y+1].startTime);
                    if (timeToNextUser > 300 ) {
                     pst.safeTransferFrom(pst.ownerOf(x), pst._parkingSpotOwners(x), x);
                    } else {
                    address nextUser = reservedParkingTimes[x][y+1].walletAddress;
                    uint256 nextStartTime = reservedParkingTimes[x][y+1].startTime;
                    uint256 nextEndTime = reservedParkingTimes[x][y+1].endTime;

                    startParkingSession(x, nextUser,nextStartTime,nextEndTime);
                    pst.safeTransferFrom(pst.ownerOf(x), nextUser, x);

                    removeOldReservation(x, y);

                    }

                } else {
                    pst.safeTransferFrom(pst.ownerOf(x), pst._parkingSpotOwners(x), x);

                }


                } else {
                    address nextUser = reservedParkingTimes[x][y].walletAddress;
                    uint256 nextStartTime = reservedParkingTimes[x][y].startTime;
                    uint256 nextEndTime = reservedParkingTimes[x][y].endTime;

                    startParkingSession(x, nextUser,nextStartTime,nextEndTime);
                    pst.safeTransferFrom(pst.ownerOf(x), nextUser, x);

                    removeOldReservation(x, y);

                }

                   } 



                /// end of present session
                if ( block.timestamp > reservedParkingTimes[x][y].endTime) {
                    
                endParkingSession(x);

                /// transfer token back to owner
                pst.safeTransferFrom(pst.ownerOf(x), pst._parkingSpotOwners(x), x);


                }


            }
            


        }

    }

    function endParkingSession(uint256 _tokenId) internal {

        /// charges user and updates mappings
        address currentUser = pst.ownerOf(_tokenId);
        address tokenOwner = pst._parkingSpotOwners(_tokenId);
        psa.setSpotInUse(_tokenId, false);
        setSessionInProgress(currentUser, false);
        depositors[currentUser] -= sessionCost[_tokenId];
        depositors[tokenOwner] += sessionCost[_tokenId];
        spotLastUsedBy[_tokenId] = currentUser;

    }

    function startParkingSession(uint256 _tokenId, address _currentUser, uint256 _startTime, uint256 _endTime) internal {

        psa.setSpotInUse(_tokenId, true);
        setSessionInProgress(_currentUser, true);
        sessionCost[_tokenId] = calculateSessionCost(_tokenId, _startTime, _endTime);
        activeSessions.push(_tokenId);

    }

    function removeOldReservation(uint256 _tokenId, uint256 _index) internal {
        delete tempReservedParkingTimes[_tokenId];

        TimeSlots memory tempTimeSlot ;


            uint i = _index;
            i = i + 1;
        for (i; i < reservedParkingTimes[_tokenId].length; i++ ) {
        
        tempTimeSlot.walletAddress = reservedParkingTimes[_tokenId][i].walletAddress;
        tempTimeSlot.startTime = reservedParkingTimes[_tokenId][i].startTime;
        tempTimeSlot.endTime = reservedParkingTimes[_tokenId][i].endTime;
        tempReservedParkingTimes[_tokenId].push(tempTimeSlot);

            }

        reservedParkingTimes[_tokenId] = tempReservedParkingTimes[_tokenId];

    }


///@dev allows a user to make a dispute during a parking session
///@dev Experimental. Not tested for safety. Treat with caution. 

    function reportParkingSpotOveruse(uint256 _tokenId, bytes memory registrationNumber ) public {

        string memory addressString = Strings.toHexString(uint160(spotLastUsedBy[_tokenId]), 20);
        bytes memory addressBytes = bytes(addressString);
        
        bytes memory hashPayload =  bytes.concat(addressBytes,registrationNumber);

        testHashPayload = hashPayload;


        bytes32 hashToCheck = sha256(hashPayload);

        if (hashPayload == hashedVehicleRegistration[spotLastUsedBy[_tokenId]]) {
            revert("Spot overused!!!");
        }


    }

    function setVehicleRegistrationHash(bytes32 _hash) external {
        hashedVehicleRegistration[msg.sender] = _hash;
    }

    function checkVehicleRegistrationHash(address _address) internal returns (bool) {
        if (!(hashedVehicleRegistration[_address] == 0)) {
            return true;
        }
    } 


}

function getReservedParkingTimes(uint256 _tokenId, uint256 _index) public view returns (address, uint256, uint256) {
        return (reservedParkingTimes[_tokenId][_index].walletAddress,reservedParkingTimes[_tokenId][_index].startTime, reservedParkingTimes[_tokenId][_index].endTime );
    }





