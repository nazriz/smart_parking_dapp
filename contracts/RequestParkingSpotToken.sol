//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface ParkingSpotAttributes {
    function checkSpotAvailability(uint) external view returns (bool);
}

interface ParkingSpotToken {
    function ownerOf(uint256) external returns (address);
    function safeTransferFrom(address,address,uint256) external;

}

contract RequestParkingSpotToken {

    mapping(address=>uint256) public depositors;

    ParkingSpotAttributes constant psa = ParkingSpotAttributes(0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9);
    ParkingSpotToken constant pst = ParkingSpotToken(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9);


    // Payable address can receive Ether
    address payable public owner;

    // Payable constructor can receive Ether
    constructor() payable {
        owner = payable(msg.sender);
    }

    // Function to deposit Ether into this contract.
    // Call this function along with some Ether.
    // The balance of this contract will be automatically updated.
    function deposit() public payable {
        depositors[msg.sender] += msg.value;
    }

    // Function to withdraw all Ether from this contract.
    function withdraw(uint256 _amount) public {
        require(_amount <= depositors[msg.sender], "Not enough ETH deposited");
        depositors[msg.sender] -= _amount;
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Failed to send Ether");

    }


    function requestParkingSpotToken(uint256 _tokenId) public {
        require(depositors[msg.sender] >= 1000000000000000000, "Must deposit at least 1 Eth");
        require(psa.checkSpotAvailability(_tokenId) == true, "Parking spot is unavailable!");

        address currentOwner;
        currentOwner = pst.ownerOf(_tokenId);
        pst.safeTransferFrom(currentOwner, msg.sender, _tokenId);

    }

}
