//SPDX-License-Identifier: MIT
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



contract RequestParkingSpotToken {
using BokkyPooBahsDateTimeLibrary for *;

event EthDeposit(address user, uint256 amount);
event EthWithdraw(address user, uint256 amount);
event EstimatedSessionCost(uint256 tokenId, uint256 cost);
event ActiveParkingSesion(uint256 tokenId, uint8 requestedStartHour, uint8 requestedStartMinute, uint8 requestedEndHour, uint8 requestedEndMinute);
event EndActiveParkingSesion(uint256 tokenId);

    struct DateTime {
        uint256 Year;
        uint256 Month; 
        uint256 Day;
        uint256 Hour; 
        uint256 Minute;
        uint256 Second;
    }

    struct TimeSlots {
        address walletAddress;
        uint256 startTime;
        uint256 endTime; 
    }

    DateTime current = DateTime(0,0,0,0,0,0);

    mapping(address=>uint256) public depositors;
    mapping(uint256=> address) public currentParkingSpotOwner;
    // mapping(uint256=>uint256[2]) public permittedParkingTimes;
    mapping(uint256=>uint256[2]) public requestedParkingTimes;
    mapping(address=>bool) public sessionInProgress;
    mapping(uint256=>uint256) public sessionCost;
    mapping(uint256=>TimeSlots) availableSlots;
    uint256[] public activeSessions;
    mapping(uint256=>TimeSlots[]) public reservedParkingTimes;
    mapping(uint256=>TimeSlots[]) public tempReservedParkingTimes;
    mapping(address=>bytes32) public hashedVehicleRegistration;
    mapping(uint256=>address) public spotLastUsedBy;


    bytes public testHashPayload;
    AggregatorV3Interface internal ethUSDpriceFeed;

    // //localhost:
    ParkingSpotAttributes constant psa = ParkingSpotAttributes(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707);
    ParkingSpotToken constant pst = ParkingSpotToken(0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9);
    // Goerli:
    // ParkingSpotAttributes constant psa = ParkingSpotAttributes(0x0A0Bbb42636AB8C3516882519ADD39DF56dCc5A5);
    // ParkingSpotToken constant pst = ParkingSpotToken(0x7380e28aB1F6ED032671b085390194F07aBC2606);

    // Payable address can receive Ether
    address payable public owner;

    // Payable constructor can receive Ether
    // constructor() payable {
    //     owner = payable(msg.sender);
    //     ethUSDpriceFeed = AggregatorV3Interface(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
    // }

    constructor() payable {
        owner = payable(msg.sender);
        //localhost
        ethUSDpriceFeed = AggregatorV3Interface(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
        //goerli
        // ethUSDpriceFeed = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e);
    }

    function deposit() public payable {
        depositors[msg.sender] += msg.value;
        emit EthDeposit(msg.sender, msg.value);
    }

    function withdraw(uint256 _amount) public {
        require(_amount <= depositors[msg.sender], "Not enough ETH deposited");
        depositors[msg.sender] -= _amount;
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Failed to send Ether");
        require(sessionInProgress[msg.sender] == false, "You cannot withdraw ETH while parking session in progress. Please wait until the session is completed, or end the session manually!");
        emit EthWithdraw(msg.sender, _amount);

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

        uint permittedStartTimeUnix = accountForTimezone(genericTimeFrameToCurrentUnixTime(permittedStartHour, permittedStartMinute), _tokenId);
        uint permittedEndTimeUnix = accountForTimezone(genericTimeFrameToCurrentUnixTime(permittedEndHour, permittedEndMinute), _tokenId);

        // permittedStartTimeUnix = accountForTimezone(permittedStartTimeUnix, _tokenId);
        // permittedEndTimeUnix  =  accountForTimezone(permittedEndTimeUnix, _tokenId);

        // permittedParkingTimes[_tokenId] = [permittedStartTimeUnix, permittedEndTimeUnix];

        return (permittedStartTimeUnix, permittedEndTimeUnix);
    }

    function setIsNegative(bool _isNegative) internal {
        _isNegative = true;
    }

    function setSessionInProgress(address _address, bool _status) internal {
        sessionInProgress[_address] = _status;
    }

    // function getStartTimeLength(uint256 _tokenId) public view returns (uint256) {
    //     return availableSlots[_tokenId].startTime.length;
    // }

    // function getEndTimeLength(uint256 _tokenId) public view returns (uint256) {
    //     return availableSlots[_tokenId].endTime.length;
    // }

    function getReservedParkingTimes(uint256 _tokenId, uint256 _index) public view returns (address, uint256, uint256) {
        return (reservedParkingTimes[_tokenId][_index].walletAddress,reservedParkingTimes[_tokenId][_index].startTime, reservedParkingTimes[_tokenId][_index].endTime );
    }

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


    function calculateSessionCost(uint256 _tokenId, uint256 _startTimeUnix, uint256 _endTimeUnix) public returns (uint256) {
        uint256 hourlyRateUSD = (psa.pricePerHour(_tokenId) * (10**8));
        int256 ethUSDPrice = getLatestPrice();
        uint256 hourlyRateGwei = (1000000000000000000 / (uint256(ethUSDPrice) / hourlyRateUSD));   
        uint256 gweiBySecond = ((hourlyRateGwei / 3600) / 10**2);

        uint256 duration = (_endTimeUnix - _startTimeUnix);


        emit EstimatedSessionCost(_tokenId, duration * gweiBySecond);

        return duration * gweiBySecond;
    }

    // function requestParkingSpotToken(uint256 _tokenId, uint8 _requestedStartHour, uint8 _requestedStartMinute, uint8 _requestedEndHour, uint8 _requestedEndMinute) public {
    //     require(_requestedStartHour <= 23, "Start hour must be between 0 and 23");
    //     require(_requestedStartMinute <= 59, "Start minute must be between 0 and 59");
    //     require(_requestedEndHour <= 23, "End hour must be between 0 and 23");
    //     require(_requestedEndMinute <= 59, "End minute must be between 0 and 59");
    //     require(psa.spotInUse(_tokenId) == false, "Parking spot currently in use!");

    //     (uint256 parkingSpotStartTime, uint256 parkingSpotEndTime) = retrievePermittedParkingTimes(_tokenId);

    //     uint256 requestedStartTimeUnix = accountForTimezone(genericTimeFrameToCurrentUnixTime(_requestedStartHour,_requestedStartMinute), _tokenId);
    //     uint256 requestedEndTimeUnix = accountForTimezone(genericTimeFrameToCurrentUnixTime(_requestedEndHour,_requestedEndMinute), _tokenId);
    //     // require(requestedStartTimeUnix > block.timestamp, "Can't request parking spot in the past!");
    //     // require(depositors[msg.sender] >= 1000000000000000000, "Must deposit at least 1 Eth");
    //     require(depositors[msg.sender] >= 10000000000000000, "Must deposit at least 0.01 Eth");
    //     uint256 calculatedSessionCost = calculateSessionCost(_tokenId,requestedStartTimeUnix,requestedEndTimeUnix);
    //     require(depositors[msg.sender] >= calculatedSessionCost , "You don't have enough ETH deposited to pay for your requested duration!" );
    // //     require(psa.checkSpotAvailability(_tokenId) == true, "Parking spot is unavailable!");
    //     require(requestedStartTimeUnix > parkingSpotStartTime && requestedEndTimeUnix < parkingSpotEndTime , "Parking spot unavailable at this time!");

    //    address currentOwner = pst.ownerOf(_tokenId);
    //     currentParkingSpotOwner[_tokenId] = currentOwner;
    //     pst.safeTransferFrom(currentOwner, msg.sender, _tokenId);
    //     psa.setSpotInUse(_tokenId, true);
    //     requestedParkingTimes[_tokenId] = [requestedStartTimeUnix, requestedEndTimeUnix ];
    //     setSessionInProgress(msg.sender, true);
    //     sessionCost[_tokenId] = calculatedSessionCost;
    //     activeSessions.push(_tokenId);

    //    TimeSlots memory tempTimeSlot ;
    //    tempTimeSlot.walletAddress = msg.sender;
    //    tempTimeSlot.startTime = requestedStartTimeUnix;
    //    tempTimeSlot.endTime = requestedEndTimeUnix;

    //     reservedParkingTimes[_tokenId].push(tempTimeSlot);
    
    //     emit ActiveParkingSesion(_tokenId, _requestedStartHour, _requestedStartMinute, _requestedEndHour, _requestedEndMinute);
    // }



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

     function addTimeSlotToEnd(uint256 _tokenId, address caller, uint256 requestedStartTime, uint256 requestedEndTime) internal returns (bool) {

        TimeSlots memory tempTimeSlot;

        tempTimeSlot.walletAddress = caller;
        tempTimeSlot.startTime = requestedStartTime;
        tempTimeSlot.endTime = requestedEndTime;
        reservedParkingTimes[_tokenId].push(tempTimeSlot);
        return true;

     }

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



    // function endParkingSession(uint256 _tokenId) public returns (bool) {
    //     require(msg.sender == pst.ownerOf(_tokenId);)

    // }

    // function returnParkingSpotToken(uint256 _tokenId) public returns (bool) {

    //     uint256 parkingEndtimeUnix = requestedParkingTimes[_tokenId][1];

    //     if (block.timestamp >= parkingEndtimeUnix) {
    //         address currentUser = pst.ownerOf(_tokenId);
    //             pst.safeTransferFrom(currentUser, pst._parkingSpotOwners(_tokenId), _tokenId);
    //             psa.setSpotInUse(_tokenId, false);
    //             setSessionInProgress(currentUser, false);
    //             depositors[currentUser] -= sessionCost[_tokenId];
    //             payable(pst.paymentAddress(_tokenId)).transfer(sessionCost[_tokenId]);
    //             return true;
    //         } else {
    //             revert("Session is not over!");
                
    // //         } 
    // //     } else if (parkingEndtimeUnix == 0) {
    // //             address currentUser = pst.ownerOf(_tokenId);
    // //             pst.safeTransferFrom(currentUser, parkingSpotOwner[_tokenId], _tokenId);
    // //             psa.setSpotInUse(_tokenId, false);
    // //             return true;
    // //         } else {
    // //             revert("Session has is not over!");
    // // }

    //     revert("Session is not over!");

    //         }

    // emit EndActiveParkingSesion(_tokenId);

// }

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

// function removeActiveSession(uint _index) public {
//         require(_index < activeSessions.length, "index out of bound");

//         for (uint i = _index; i < activeSessions.length - 1; i++) {
//             activeSessions[i] = activeSessions[i + 1];
//         }
//         activeSessions.pop();
//     }

//     function checkIfParkingSessionOver() external {
//         for (uint i = 0; i < activeSessions.length; i++) {
//         uint256 parkingEndtimeUnix = requestedParkingTimes[activeSessions[i]][1];

//         if (block.timestamp > parkingEndtimeUnix) {
//             returnParkingSpotToken(activeSessions[i]);
//             removeActiveSession(i);
//         }


//         }

//     }

    function distributeParkingSpots() external {
        uint256 tokenCount = pst.getTokenCount();

        for (uint x = 1; x <= tokenCount; x ++) {
            for (uint y=0; y < reservedParkingTimes[x].length; y++ ) {
                
                // start of new session
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



                // end of present session
                if ( block.timestamp > reservedParkingTimes[x][y].endTime) {
                    
                endParkingSession(x);

                // transfer token back to owner
                pst.safeTransferFrom(pst.ownerOf(x), pst._parkingSpotOwners(x), x);


                }


            }
            


        }

    }

    function endParkingSession(uint256 _tokenId) internal {

        // charges user and updates mappings
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

    function reportParkingSpotOveruse(uint256 _tokenId, bytes memory registrationNumber ) public {

        string memory addressString = Strings.toHexString(uint160(spotLastUsedBy[_tokenId]), 20);
        bytes memory addressBytes = bytes(addressString);
        
        bytes memory hashPayload =  bytes.concat(addressBytes,registrationNumber);

        testHashPayload = hashPayload;


        // bytes32 hashToCheck = sha256(hashPayload);

        // if (hashPayload == hashedVehicleRegistration[spotLastUsedBy[_tokenId]]) {
        //     revert("Spot overused!!!");
        // }


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

