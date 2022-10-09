//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./BokkyPooBahsDateTimeContract.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "hardhat/console.sol";

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


    uint256 public testLoop;

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


    function calculateSessionCost(uint256 _tokenId, uint256 _startTimeUnix, uint256 _endTimeUnix) public returns (uint256)  {
        uint256 hourlyRateUSD = (psa.pricePerHour(_tokenId) * (10**8));
        int256 ethUSDPrice = getLatestPrice();
        uint256 hourlyRateGwei = (1000000000000000000 / (uint256(ethUSDPrice) / hourlyRateUSD));   
        uint256 gweiBySecond = ((hourlyRateGwei / 3600) / 10**2);

        uint256 duration = (_endTimeUnix - _startTimeUnix);

        emit EstimatedSessionCost(_tokenId, duration * gweiBySecond);

        return duration * gweiBySecond;
    }

    function requestParkingSpotToken(uint256 _tokenId, uint8 _requestedStartHour, uint8 _requestedStartMinute, uint8 _requestedEndHour, uint8 _requestedEndMinute) public {
        require(_requestedStartHour <= 23, "Start hour must be between 0 and 23");
        require(_requestedStartMinute <= 59, "Start minute must be between 0 and 59");
        require(_requestedEndHour <= 23, "End hour must be between 0 and 23");
        require(_requestedEndMinute <= 59, "End minute must be between 0 and 59");
        require(psa.spotInUse(_tokenId) == false, "Parking spot currently in use!");

        (uint256 parkingSpotStartTime, uint256 parkingSpotEndTime) = retrievePermittedParkingTimes(_tokenId);

        uint256 requestedStartTimeUnix = accountForTimezone(genericTimeFrameToCurrentUnixTime(_requestedStartHour,_requestedStartMinute), _tokenId);
        uint256 requestedEndTimeUnix = accountForTimezone(genericTimeFrameToCurrentUnixTime(_requestedEndHour,_requestedEndMinute), _tokenId);
        // require(requestedStartTimeUnix > block.timestamp, "Can't request parking spot in the past!");
        // require(depositors[msg.sender] >= 1000000000000000000, "Must deposit at least 1 Eth");
        require(depositors[msg.sender] >= 10000000000000000, "Must deposit at least 0.01 Eth");
        uint256 calculatedSessionCost = calculateSessionCost(_tokenId,requestedStartTimeUnix,requestedEndTimeUnix);
        require(depositors[msg.sender] >= calculatedSessionCost , "You don't have enough ETH deposited to pay for your requested duration!" );
        require(psa.checkSpotAvailability(_tokenId) == true, "Parking spot is unavailable!");
        require(requestedStartTimeUnix > parkingSpotStartTime && requestedEndTimeUnix < parkingSpotEndTime , "Parking spot unavailable at this time!");

       address currentOwner = pst.ownerOf(_tokenId);
        currentParkingSpotOwner[_tokenId] = currentOwner;
        pst.safeTransferFrom(currentOwner, msg.sender, _tokenId);
        psa.setSpotInUse(_tokenId, true);
        requestedParkingTimes[_tokenId] = [requestedStartTimeUnix, requestedEndTimeUnix ];
        setSessionInProgress(msg.sender, true);
        sessionCost[_tokenId] = calculatedSessionCost;
        activeSessions.push(_tokenId);

       TimeSlots memory tempTimeSlot ;
       tempTimeSlot.walletAddress = msg.sender;
       tempTimeSlot.startTime = requestedStartTimeUnix;
       tempTimeSlot.endTime = requestedEndTimeUnix;

        reservedParkingTimes[_tokenId].push(tempTimeSlot);
      



        emit ActiveParkingSesion(_tokenId, _requestedStartHour, _requestedStartMinute, _requestedEndHour, _requestedEndMinute);
    }

    // function checkAvailableSpots(uint256 _tokenId, uint256 _requestedStartTime, uint256 _requestedEndTime) public {
        
    //     uint256 [] memory spotStartTimes = availableSlots[_tokenId].startTime;
    //     uint256 [] memory spotEndTimes = availableSlots[_tokenId].endTime;

    //     uint256 startTimeLength = getStartTimeLength(_tokenId);

    //     for (uint i = 0; i < startTimeLength; i++) {
    //         if (_requestedStartTime > spotEndTimes[i] && _requestedEndTime < spotStartTimes[i+1]) {
    //             testLoop = 1111;
    //         } else {
    //             testLoop = 2222;
    //         }
    //     }

    // }

    function slotInMiddleForOther(uint256 _tokenId, address caller, uint256 requestedStartTime, uint256 requestedEndTime, uint timeSlotsLength, uint _index) internal returns (bool) {
                                delete tempReservedParkingTimes[_tokenId];

                                console.log("index: %i", _index);

                                TimeSlots memory tempTimeSlot;

                                for (uint x = 0; x <= _index; x++) {
                                tempTimeSlot.walletAddress = reservedParkingTimes[_tokenId][x].walletAddress;
                                tempTimeSlot.startTime = reservedParkingTimes[_tokenId][x].startTime;
                                tempTimeSlot.endTime = reservedParkingTimes[_tokenId][x].endTime;

                                tempReservedParkingTimes[_tokenId].push(tempTimeSlot);

                                }

                        // uint [2] memory reservedParkingMapping0 = [tempReservedParkingTimes[_tokenId][0].startTime, tempReservedParkingTimes[_tokenId][0].endTime];
                        // uint [2] memory reservedParkingMapping1 = [tempReservedParkingTimes[_tokenId][1].startTime, tempReservedParkingTimes[_tokenId][1].endTime];

                        // console.log("tempReservedParkingTimesMapping at idx 0 startTime: %i endTime %i", reservedParkingMapping0[0],reservedParkingMapping0[1]);
                        // console.log("tempReservedParkingTimesMapping at idx 1 startTime: %i endTime %i", reservedParkingMapping1[0],reservedParkingMapping1[1]);
                                

                                tempTimeSlot.walletAddress = caller;
                                tempTimeSlot.startTime = requestedStartTime;
                                tempTimeSlot.endTime = requestedEndTime;

                                tempReservedParkingTimes[_tokenId].push(tempTimeSlot);

                        // uint [2] memory reservedParkingMapping2 = [tempReservedParkingTimes[_tokenId][2].startTime, tempReservedParkingTimes[_tokenId][2].endTime];

                        // console.log("tempReservedParkingTimesMapping at idx 2 startTime: %i endTime %i", reservedParkingMapping2[0],reservedParkingMapping0[1]);


                                uint j = _index + 1;
                                for (j; j < timeSlotsLength; j++ ) {
                                
                                tempTimeSlot.walletAddress = reservedParkingTimes[_tokenId][j].walletAddress;
                                tempTimeSlot.startTime = reservedParkingTimes[_tokenId][j].startTime;
                                tempTimeSlot.endTime = reservedParkingTimes[_tokenId][j].endTime;
                                tempReservedParkingTimes[_tokenId].push(tempTimeSlot);

                                 }

                        // uint [2] memory reservedParkingMapping3 = [tempReservedParkingTimes[_tokenId][3].startTime, tempReservedParkingTimes[_tokenId][3].endTime];
                        // uint [2] memory reservedParkingMapping4 = [tempReservedParkingTimes[_tokenId][4].startTime, tempReservedParkingTimes[_tokenId][4].endTime];

                        // console.log("tempReservedParkingTimesMapping at idx 3 startTime: %i endTime %i", reservedParkingMapping3[0],reservedParkingMapping3[1]);
                        // console.log("tempReservedParkingTimesMapping at idx 4 startTime: %i endTime %i", reservedParkingMapping4[0],reservedParkingMapping4[1]);
                                 

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
                // uint currentIdxPlusOne = 0;
            console.log("timeslotslength: %i, i: %i", timeSlotsLength, i);
            for (i; i < timeSlotsLength; i++) {
            console.log(" in loop timeslotslength: %i, i: %i", timeSlotsLength, i);
                    uint overflowCheck = i;
                    overflowCheck++;
                        console.log(" in loop ++ timeslotslength: %i, i: %i, overflowcheck: %i", timeSlotsLength, i, overflowCheck);
                        uint reservedEndTime = reservedParkingTimes[_tokenId][i].endTime;
                        uint reservedStartTime = reservedParkingTimes[_tokenId][overflowCheck].startTime;
                        
                        // console.log("before first if statement (line 250): requestedStartTime: %i, reservedParkingTimes[i]endTime: %i, requestedEndTime: %i, reservedParkingTimes[i+1]startTime: %i",requestedStartTime, reservedEndTime, requestedEndTime,  reservedStartTime  );
                        console.log("before first if statement (line 250): requestedStartTime: %i, requestedEndTime: %i",requestedStartTime, requestedEndTime );
                        console.log("before first if statement (line 250): reservedEndTime: %i, reservedStartTime: %i",reservedEndTime, reservedStartTime );

                        // currentIdxPlusOne = i+1;
                        uint [2] memory reservedParkingMapping0 = [reservedParkingTimes[_tokenId][0].startTime, reservedParkingTimes[_tokenId][0].endTime];
                        uint [2] memory reservedParkingMapping1 = [reservedParkingTimes[_tokenId][1].startTime, reservedParkingTimes[_tokenId][1].endTime];

                        console.log("reservedParkingMapping at idx 0 startTime: %i endTime %i", reservedParkingMapping0[0],reservedParkingMapping0[1]);
                        console.log("reservedParkingMapping at idx 1 startTime: %i endTime %i", reservedParkingMapping1[0],reservedParkingMapping1[1]);
                        console.log("i: %i", i);

                     if (requestedStartTime > reservedParkingTimes[_tokenId][i].endTime) {
                        console.log("overflow check: %i, timeSlotsLength: %i", overflowCheck, timeSlotsLength);
                        console.log("i: %i", i);

                        if (overflowCheck > timeSlotsLength) {
                        revert("append to the end fam");
                        } else {
                            if(requestedEndTime < reservedParkingTimes[_tokenId][overflowCheck].startTime) {
                                if  (i == 0) {
                                 slotInMiddleForZero(_tokenId, caller, requestedStartTime, requestedEndTime, timeSlotsLength);
                                 return true;
                            } else if (i > 0) {
                                slotInMiddleForOther(_tokenId, caller, requestedStartTime, requestedEndTime, timeSlotsLength, i);
                                return true;
                            } else {
                                revert("something went wrong");
                            }



                                
                            }

                            continue;
                        }

                            console.log("i: %i", i);

                            continue;
                 } else if (requestedStartTime > reservedParkingTimes[_tokenId][i].endTime && i++ > timeSlotsLength ) {
                        revert("append to the end fam");
                 } else {
                    revert("idk mayn");
                 } 

                        
                 
                 revert("If ur reading this, it means ur on to something");

            }

            revert("down here man");

  


     }


    // function slotTimeSlotinMiddle(uint256 _tokenId, address caller, uint256 requestedStartTime, uint256 requestedEndTime, uint timeSlotsLength) internal {
    //                     uint i = 0;
    //                 for (i; i < timeSlotsLength; i++) {
    //             if (reservedParkingTimes[_tokenId][i].endTime < requestedStartTime) {

    //                 if (i+1 >= timeSlotsLength) {
    //                     revert("got em");
    //             // TimeSlots memory tempTimeSlot;
    //             // tempTimeSlot.walletAddress = caller;
    //             // tempTimeSlot.startTime = requestedStartTime;
    //             // tempTimeSlot.endTime = requestedEndTime;
    //             // reservedParkingTimes[_tokenId].push(tempTimeSlot);
    //                 } else if (reservedParkingTimes[_tokenId][i+1].startTime > requestedEndTime) {
    //                     delete tempReservedParkingTimes[_tokenId];
                    
    //                 // int tempTimeSlotsArrayLength = int(timeSlotsLength)+1;
    //                 TimeSlots memory tempTimeSlot ;

    //                 tempTimeSlot.walletAddress = caller;
    //                 tempTimeSlot.startTime = requestedStartTime;
    //                 tempTimeSlot.endTime = requestedEndTime;

    //                 if  (i == 0) {

    //                 TimeSlots memory holderTimeSlot;
                    
    //                 holderTimeSlot.walletAddress = reservedParkingTimes[_tokenId][i].walletAddress;
    //                 holderTimeSlot.startTime = reservedParkingTimes[_tokenId][i].startTime;
    //                 holderTimeSlot.endTime = reservedParkingTimes[_tokenId][i].endTime;
                    
    //                 tempReservedParkingTimes[_tokenId].push(tempTimeSlot);

    //                 uint j = i+1;
    //                 for (j; j < timeSlotsLength; j++ ) {
    //                 TimeSlots memory holderTimeSlot;
                    
    //                 holderTimeSlot.walletAddress = reservedParkingTimes[_tokenId][j].walletAddress;
    //                 holderTimeSlot.startTime = reservedParkingTimes[_tokenId][j].startTime;
    //                 holderTimeSlot.endTime = reservedParkingTimes[_tokenId][j].endTime;
    //                 }


 
    //                 } else {
    //                     revert("no bueno");
    //                 }

    //                 // for (uint x = 0; x <= i; x++) {
    //                 // TimeSlots memory holderTimeSlot;
                    
    //                 // holderTimeSlot.walletAddress = reservedParkingTimes[_tokenId][x].walletAddress;
    //                 // holderTimeSlot.startTime = reservedParkingTimes[_tokenId][x].startTime;
    //                 // holderTimeSlot.endTime = reservedParkingTimes[_tokenId][x].endTime;

    //                 //     tempReservedParkingTimes[_tokenId].push(holderTimeSlot);

    //                 // }

    //                 //     tempReservedParkingTimes[_tokenId].push(tempTimeSlot);

    //                 //     uint y = i+1;

    //                 //   for (y; y <= timeSlotsLength; y++) {

    //                 //     TimeSlots memory holderTimeSlot;
                    
    //                 // holderTimeSlot.walletAddress = reservedParkingTimes[_tokenId][y].walletAddress;
    //                 // holderTimeSlot.startTime = reservedParkingTimes[_tokenId][y].startTime;
    //                 // holderTimeSlot.endTime = reservedParkingTimes[_tokenId][y].endTime;
    //                 //     // tempTimeSlotArray.push(reservedParkingTimes[_tokenId][y]);
    //                 //     tempReservedParkingTimes[_tokenId].push(holderTimeSlot);
    //                 // }

    //                 // reservedParkingTimes[_tokenId] = tempReservedParkingTimes[_tokenId];

    //                 } else {

    //             // TimeSlots memory tempTimeSlot ;
    //             // tempTimeSlot.walletAddress = caller;
    //             // tempTimeSlot.startTime = requestedStartTime;
    //             // tempTimeSlot.endTime = requestedEndTime;
    //             // reservedParkingTimes[_tokenId].push(tempTimeSlot);

    //             revert("teehee");
                        
    //                 }
    //             } 
    //             else {
    //                 revert("Nah bruh");
    //             }


    //         }

    //         revert("I be flossin'");

    // }

    function reserveParkingSpotToken(uint256 _tokenId, uint8 _requestedStartHour, uint8 _requestedStartMinute, uint8 _requestedEndHour, uint8 _requestedEndMinute) public {
        require(_requestedStartHour <= 23, "Start hour must be between 0 and 23");
        require(_requestedStartMinute <= 59, "Start minute must be between 0 and 59");
        require(_requestedEndHour <= 23, "End hour must be between 0 and 23");
        require(_requestedEndMinute <= 59, "End minute must be between 0 and 59");
     
        (uint256 parkingSpotStartTime, uint256 parkingSpotEndTime) = retrievePermittedParkingTimes(_tokenId);
        uint256 requestedStartTimeUnix = accountForTimezone(genericTimeFrameToCurrentUnixTime(_requestedStartHour,_requestedStartMinute), _tokenId);
        uint256 requestedEndTimeUnix = accountForTimezone(genericTimeFrameToCurrentUnixTime(_requestedEndHour,_requestedEndMinute), _tokenId);

        // requestedStartTimeUnix += _requestedStartFromCurrentDateSeconds;
        // requestedEndTimeUnix += _requestedEndFromCurrentDateSeconds;

        uint timeSlotsLength = reservedParkingTimes[_tokenId].length;

        if (timeSlotsLength == 0) {

        TimeSlots memory tempTimeSlot ;
        tempTimeSlot.walletAddress = msg.sender;
        tempTimeSlot.startTime = requestedStartTimeUnix;
        tempTimeSlot.endTime = requestedEndTimeUnix;
        reservedParkingTimes[_tokenId].push(tempTimeSlot);

        } else if (timeSlotsLength == 1) {
            if (reservedParkingTimes[_tokenId][0].endTime < requestedStartTimeUnix) {
                TimeSlots memory tempTimeSlot ;
                tempTimeSlot.walletAddress = msg.sender;
                tempTimeSlot.startTime = requestedStartTimeUnix;
                tempTimeSlot.endTime = requestedEndTimeUnix;
                reservedParkingTimes[_tokenId].push(tempTimeSlot);
            } else {
                revert("Time Slot unavailable, please try again");
            }
        } else {
            slotTimeSlotinMiddle(_tokenId, msg.sender, requestedStartTimeUnix, requestedEndTimeUnix, timeSlotsLength);
        }

    }


    // function endParkingSession(uint256 _tokenId) public returns (bool) {
    //     require(msg.sender == pst.ownerOf(_tokenId);)

    // }

    function returnParkingSpotToken(uint256 _tokenId) public returns (bool) {

        uint256 parkingEndtimeUnix = requestedParkingTimes[_tokenId][1];

        if (block.timestamp >= parkingEndtimeUnix) {
            address currentUser = pst.ownerOf(_tokenId);
                pst.safeTransferFrom(currentUser, pst._parkingSpotOwners(_tokenId), _tokenId);
                psa.setSpotInUse(_tokenId, false);
                setSessionInProgress(currentUser, false);
                depositors[currentUser] -= sessionCost[_tokenId];
                payable(pst.paymentAddress(_tokenId)).transfer(sessionCost[_tokenId]);
                return true;
            } else {
                revert("Session is not over!");
                
    //         } 
    //     } else if (parkingEndtimeUnix == 0) {
    //             address currentUser = pst.ownerOf(_tokenId);
    //             pst.safeTransferFrom(currentUser, parkingSpotOwner[_tokenId], _tokenId);
    //             psa.setSpotInUse(_tokenId, false);
    //             return true;
    //         } else {
    //             revert("Session has is not over!");
    // }

        revert("Session is not over!");

            }

    emit EndActiveParkingSesion(_tokenId);

}

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

function removeActiveSession(uint _index) public {
        require(_index < activeSessions.length, "index out of bound");

        for (uint i = _index; i < activeSessions.length - 1; i++) {
            activeSessions[i] = activeSessions[i + 1];
        }
        activeSessions.pop();
    }

    function checkIfParkingSessionOver() external {
        for (uint i = 0; i < activeSessions.length; i++) {
        uint256 parkingEndtimeUnix = requestedParkingTimes[activeSessions[i]][1];

        if (block.timestamp > parkingEndtimeUnix) {
            returnParkingSpotToken(activeSessions[i]);
            removeActiveSession(i);
        }


        }

    }


}

