//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
 */

/**
 * @notice DO NOT USE THIS CODE IN PRODUCTION. This is an example contract.
 */
contract GenericLargeResponse is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    // variable bytes(arbitrary-length raw byte data) returned in a single oracle response
    bytes public data;
    string public image_url;

    bytes32 private jobId;
    uint256 private fee;

    /**
     * @notice Initialize the link token and target oracle
     * @dev The oracle address must be an Operator contract for multiword response
     *
     *
     * Rinkeby Testnet details:
     * Link Token: 0x01BE23585060835E02B77ef475b0Cc51aA1e0709
     * Oracle: 0xf3FBB7f3391F62C8fe53f89B41dFC8159EE9653f (Chainlink DevRel)
     * jobId: 7da2702f37fd48e5b1b9a5715e3509b6
     *
     */
    constructor() ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x01BE23585060835E02B77ef475b0Cc51aA1e0709);
        setChainlinkOracle(0xf98Cd24CF1f864DF4942165569Fc0114f866067d);
        jobId = "ee2f53a42c624b699bb0a3a381a9ff7f";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    /**
     * @notice Request variable bytes from the oracle
     */
    function requestBytes() public {
        Chainlink.Request memory req = buildChainlinkRequest(jobId, address(this), this.fulfillBytes.selector);
        req.add("get","https://yfkocaqzu8.execute-api.us-east-1.amazonaws.com/test/register?address=TestAddress");

        req.add("path","confirmedAddress"); // Chainlink nodes 1.0.0 and later support this format
        sendChainlinkRequest(req, fee);
    }

    event RequestFulfilled(bytes32 indexed requestId, bytes indexed data);

    /**
     * @notice Fulfillment function for variable bytes
     * @dev This is called by the oracle. recordChainlinkFulfillment must be used.
     */
    function fulfillBytes(bytes32 requestId, bytes memory bytesData) public recordChainlinkFulfillment(requestId) {
        emit RequestFulfilled(requestId, bytesData);
        data = bytesData;
        image_url = string(data);
    }

    /**
     * Allow withdraw of Link tokens from the contract
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), 'Unable to transfer');
    }
}

