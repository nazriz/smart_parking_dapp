// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface OffchainParkingDataResponse {
    function checkParkingSpotLocationOwner(address _address) external view returns ( bytes32);
    function checkParkingSpotLocationOwnerArray(address _address, uint16 _index) external view returns ( bytes32);
}
contract ParkingSpotToken is ERC721URIStorage {

    mapping(bytes32=>bool) public spotTokenised;
    mapping(uint256=>address) public paymentAddress;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("ParkingSpotToken", "PST") public {
    }

// Interface address is for local network, must be updated for network deployed to.

    OffchainParkingDataResponse constant opdr = OffchainParkingDataResponse(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);




    function confirmNotMinted(bytes32 _parkingSpot) internal view returns (bool) {
        return spotTokenised[_parkingSpot];
    }

    function retrieveLatLongBytes(uint16 _index) internal returns (bytes32) {
        return opdr.checkParkingSpotLocationOwnerArray(msg.sender, _index);
    }

    function generateTokenURI(bytes32 _parkingSpot) internal returns (string memory ) {
        require(!confirmNotMinted(_parkingSpot), "Parking spot co-ordinates are already minted as a token");
        string memory plainDataSchemeURI = "data:text/plain;charset=UTF-8,parkingSpotLatLong:";
        string memory parkingSpotString = Strings.toHexString(uint160(msg.sender), 32);
        string memory dataSchemeURI = string.concat(plainDataSchemeURI,parkingSpotString);
        return dataSchemeURI;
    }

    function prepareData(uint16 _index) internal returns (string memory) {
        bytes32 parkingSpotLatLong = retrieveLatLongBytes(_index);
        string memory finalTokenURI = generateTokenURI(parkingSpotLatLong);
        return finalTokenURI;
    }

    function _setPaymentAddress(address _paymentAddr, uint256 _tokenId) internal {
        paymentAddress[_tokenId] = _paymentAddr;


    }

    function setPaymentAddress(address _paymentAddr, uint256 _tokenId) public {
        require(_parkingSpotOwners[_tokenId] == msg.sender, "Only the true parking spot owner can change the payment address!");
        paymentAddress[_tokenId] = _paymentAddr;

    }


    function _mintParkingSpot(address user, uint16 _index) internal returns (uint256) {
        _tokenIds.increment();

        string memory tokenURI = prepareData(_index);

        uint256 newItemId = _tokenIds.current();
        _mint(user, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

    function mintParkingSpot(address _user, uint16 _index) public returns (uint256) {
        uint256 tokenId = _mintParkingSpot(_user, _index);
        _setPaymentAddress(_user, tokenId);
        return tokenId;

    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual override returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender) || isApprovedForRequestContract(tokenId, spender);
    }
    
}