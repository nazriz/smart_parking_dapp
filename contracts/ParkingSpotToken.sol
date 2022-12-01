// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface OffchainParkingDataResponse {
    function checkParkingSpotLocationOwner(address _address) external view returns ( bytes32);
    function checkParkingSpotLocationOwnerArray(address _address, uint16 _index) external view returns ( bytes32);
}

/// @title ParkingSpotToken
/// @author XXXXX XXXXXX
/// @notice Allows for the minting of a parking spot token. Requires OffchainParkingDataResponse.
contract ParkingSpotToken is ERC721URIStorage {



    ///@param owner address of token minter, tokenId id of token
    event ParkingSpotMinted(address owner, uint256 tokenId);

    mapping(bytes32=>bool) public spotTokenised;
    mapping(uint256=>address) public paymentAddress;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 public tokenCount;

    constructor() ERC721("ParkingSpotToken", "PST") public {
    }

// Interface address is for local network, must be updated for network deployed to.

    //localhost: 
    OffchainParkingDataResponse constant opdr = OffchainParkingDataResponse(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9);
    //Goerli:
    // OffchainParkingDataResponse constant opdr = OffchainParkingDataResponse(0x5ecA6776c44E49753CB2910e2BFB0Ca2D756F62b);


//@dev Checks if the parking spot bytes, i.e. co-ordinates
///@dev have been used in an existing parking spot token.
///@param _parkingSpot the bytes of the desired parking spot being minted
///@param pulled from OffChainParkingDataResponse
    function confirmNotMinted(bytes32 _parkingSpot) internal view returns (bool) {
        return spotTokenised[_parkingSpot];
    }

//@dev retrieves bytes from OffChainParkingDataResponse
///@param _index the user specified index of the bytes that are to be
///@param pulled from the parkingSpotLocationOwnerArray
    function retrieveLatLongBytes(uint16 _index) internal returns (bytes32) {
        return opdr.checkParkingSpotLocationOwnerArray(msg.sender, _index);
    }


//@dev creates the necessary tokenURI using the Data URI format
//@param _parkingSpot the bytes of the desired parking spot being minted
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

//@dev Allows true parking spot owner to set the address
//@dev  in which parking spot revenues are to be sent
//@param _paymentAddr the desired wallet address, _tokenId the id of the parking spot
    function setPaymentAddress(address _paymentAddr, uint256 _tokenId) public {
        require(_parkingSpotOwners[_tokenId] == msg.sender, "Only the true parking spot owner can change the payment address!");
        paymentAddress[_tokenId] = _paymentAddr;

    }


    function _mintParkingSpot(address user, uint16 _index) internal returns (uint256) {
        _tokenIds.increment();

        string memory tokenURI = prepareData(_index);

        uint256 newItemId = _tokenIds.current();
        tokenCount = _tokenIds.current();
        _mint(user, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }


//@dev Mints a new parking spot token
//@dev Requires requestOffchainParkingSpotData to have been called in OffChainParkingDataResponse
//@dev Will revert if specified bytes have already been tokenised
//@param _user address that is to receive the minted token, _index the index in 
//@param parkingSpotLocationOwnerArray that contains the parking spot location bytes
    function mintParkingSpot(address _user, uint16 _index) public returns (uint256) {
        uint256 tokenId = _mintParkingSpot(_user, _index);
        _setPaymentAddress(_user, tokenId);

        emit ParkingSpotMinted(_user, tokenId);
        return tokenId;
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual override returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender) || isApprovedForRequestContract(tokenId, spender);
    }

    function getTokenCount() external returns (uint256) {
        return tokenCount;
    }
    
}
