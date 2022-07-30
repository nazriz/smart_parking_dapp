// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface GenericLargeResponse {
    function checkParkingSpotLocationOwner(address _address) external view returns ( bytes32);
    function checkParkingSpotLocationOwnerArray(address _address, uint16 _index) external view returns ( bytes32);
}
contract ParkingSpotToken is ERC721URIStorage {

    GenericLargeResponse constant glr = GenericLargeResponse(0xaDF4FEDFCD28C39a484F96895A95871C2BA37A60);

    mapping(bytes32=>bool) public spotTokenised;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("ParkingSpotToken", "PST") public {
    }

    function confirmNotMinted(bytes32 _parkingSpot) internal view returns (bool) {
        return spotTokenised[_parkingSpot];
    }

    function retrieveLatLongBytes(uint16 _index) internal returns (bytes32) {
        return glr.checkParkingSpotLocationOwnerArray(msg.sender, _index);
    }

    function generateTokenURI(bytes32 _parkingSpot) internal returns (string memory ) {
        require(!confirmNotMinted(_parkingSpot));
        string memory plainDataSchemeURI = "data:text/plain;charset=UTF-8,parkingSpotLatLong:";
        string memory parkingSpotString = Strings.toHexString(uint160(msg.sender), 32);
        string memory dataSchemeURI = string.concat(plainDataSchemeURI,parkingSpotString);
        return dataSchemeURI;
    }

    function prepareData(uint16 _index) public returns (string memory) {
        bytes32 parkingSpotLatLong = retrieveLatLongBytes(_index);
        string memory finalTokenURI = generateTokenURI(parkingSpotLatLong);
        return finalTokenURI;
    }



    function mintParkingSpot(address user, uint16 _index) public returns (uint256) {
        _tokenIds.increment();

        string memory tokenURI = prepareData(_index);

        uint256 newItemId = _tokenIds.current();
        _mint(user, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }
}