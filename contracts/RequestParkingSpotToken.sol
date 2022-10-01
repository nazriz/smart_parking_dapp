//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./BokkyPooBahsDateTimeContract.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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
        uint256[] startTime;
        uint256[] endTime; 
    }

    DateTime current = DateTime(0,0,0,0,0,0);

    mapping(address=>uint256) public depositors;
    mapping(uint256=> address) public currentParkingSpotOwner;
    // mapping(uint256=>uint256[2]) public permittedParkingTimes;
    mapping(uint256=>uint256[2]) public requestedParkingTimes;
    mapping(address=>bool) public sessionInProgress;
    mapping(uint256=>uint256) public sessionCost;
    mapping(uint256=>TimeSlots) availableSlots;

    uint256 public testLoop;

    AggregatorV3Interface internal ethUSDpriceFeed;

    // ParkingSpotAttributes constant psa = ParkingSpotAttributes(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707);
    // ParkingSpotToken constant pst = ParkingSpotToken(0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9);

    ParkingSpotAttributes constant psa = ParkingSpotAttributes(0x28E67485D20fFA78A7dC61CB4aAc07b82acc6382);
    ParkingSpotToken constant pst = ParkingSpotToken(0x7380e28aB1F6ED032671b085390194F07aBC2606);

    // Payable address can receive Ether
    address payable public owner;

    // Payable constructor can receive Ether
    // constructor() payable {
    //     owner = payable(msg.sender);
    //     ethUSDpriceFeed = AggregatorV3Interface(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
    // }

    constructor() payable {
        owner = payable(msg.sender);
        // ethUSDpriceFeed = AggregatorV3Interface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e);
        ethUSDpriceFeed = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e);
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

    function getStartTimeLength(uint256 _tokenId) public view returns (uint256) {
        return availableSlots[_tokenId].startTime.length;
    }

    function getEndTimeLength(uint256 _tokenId) public view returns (uint256) {
        return availableSlots[_tokenId].endTime.length;
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

        emit ActiveParkingSesion(_tokenId, _requestedStartHour, _requestedStartMinute, _requestedEndHour, _requestedEndMinute);
    }

    function checkAvailableSpots(uint256 _tokenId, uint256 _requestedStartTime, uint256 _requestedEndTime) public {
        
        uint256 [] memory spotStartTimes = availableSlots[_tokenId].startTime;
        uint256 [] memory spotEndTimes = availableSlots[_tokenId].endTime;

        uint256 startTimeLength = getStartTimeLength(_tokenId);

        for (uint i = 0; i < startTimeLength; i++) {
            if (_requestedStartTime > spotEndTimes[i] && _requestedEndTime < spotStartTimes[i+1]) {
                testLoop = 1111;
            } else {
                testLoop = 2222;
            }
        }

    }

    function reserveParkingSpotToken(uint256 _tokenId, uint256 _requestedStartFromCurrentDateSeconds, uint8 _requestedStartHour, uint8 _requestedStartMinute, uint8 _requestedEndHour, uint8 _requestedEndMinute, uint256 _requestedEndFromCurrentDateSeconds) public {
        require(_requestedStartHour <= 23, "Start hour must be between 0 and 23");
        require(_requestedStartMinute <= 59, "Start minute must be between 0 and 59");
        require(_requestedEndHour <= 23, "End hour must be between 0 and 23");
        require(_requestedEndMinute <= 59, "End minute must be between 0 and 59");
     
        (uint256 parkingSpotStartTime, uint256 parkingSpotEndTime) = retrievePermittedParkingTimes(_tokenId);
        uint256 requestedStartTimeUnix = accountForTimezone(genericTimeFrameToCurrentUnixTime(_requestedStartHour,_requestedStartMinute), _tokenId);
        uint256 requestedEndTimeUnix = accountForTimezone(genericTimeFrameToCurrentUnixTime(_requestedEndHour,_requestedEndMinute), _tokenId);

        requestedStartTimeUnix += _requestedStartFromCurrentDateSeconds;
        requestedEndTimeUnix += _requestedEndFromCurrentDateSeconds;

        parkingSpotStartTime += _requestedStartFromCurrentDateSeconds;
        parkingSpotEndTime += _requestedEndFromCurrentDateSeconds;

        require(requestedStartTimeUnix >= parkingSpotStartTime && parkingSpotEndTime <= parkingSpotEndTime);


        // uint256 arrayLength = getAvailableSlotsLength(_tokenId);

        // for (x = 1)

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

}

