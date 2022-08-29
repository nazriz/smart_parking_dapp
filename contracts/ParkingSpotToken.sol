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


    function mintParkingSpot(address user, uint16 _index) public returns (uint256) {
        _tokenIds.increment();

        string memory tokenURI = prepareData(_index);

        uint256 newItemId = _tokenIds.current();
        _mint(user, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

    // function safeTransferFromWithOwnerApprovals(
    //     address from,
    //     address to,
    //     uint256 tokenId
    // ) public virtual {
    //     require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
    //     _safeTransferWithOwnerApprovals(from, to, tokenId, "0x");
    // }

    // function _safeTransferWithOwnerApprovals(
    //     address from,
    //     address to,
    //     uint256 tokenId,
    //     bytes memory data
    // ) internal virtual {
    //     _transferWithOwnerApprovals(from, to, tokenId);
    //     require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    // }

    // function _transferWithOwnerApprovals(
    //     address from,
    //     address to,
    //     uint256 tokenId
    // ) internal virtual {
    //     require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
    //     require(to != address(0), "ERC721: transfer to the zero address");

    //     _beforeTokenTransfer(from, to, tokenId);

    //     // Check that tokenId was not transferred by `_beforeTokenTransfer` hook
    //     require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");

    //     // Clear approvals from the previous owner
    //     // delete _tokenApprovals[tokenId];

    //     unchecked {
    //         // `_balances[from]` cannot overflow for the same reason as described in `_burn`:
    //         // `from`'s balance is the number of token held, which is at least one before the current
    //         // transfer.
    //         // `_balances[to]` could overflow in the conditions described in `_mint`. That would require
    //         // all 2**256 token ids to be minted, which in practice is impossible.
    //         _balances[from] -= 1;
    //         _balances[to] += 1;
    //     }
    //     _owners[tokenId] = to;
    //     _parkingSpotOwners[tokenId] = to;

    //     emit Transfer(from, to, tokenId);

    //     _afterTokenTransfer(from, to, tokenId);
    // }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual override returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender) || isApprovedForRequestContract(tokenId, spender);
    }
    
}