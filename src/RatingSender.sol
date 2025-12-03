// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IMailbox.sol";
import "./interfaces/IInterchainGasPaymaster.sol";

contract RatingSender {
    // ============ State ============
    IMailbox public immutable mailbox;
    IInterchainGasPaymaster public immutable igp;

    mapping(uint32 => bool) public allowedDomains;
    mapping(uint32 => address) public ratingConsumerAddrs;
    mapping(address => bool) public authorizedRaters;
    mapping(address => uint256) public borrowersNonce;

    address public owner;

    // ============ Events ============
    event RatingDispatched(
        bytes32 msgId,
        uint32 domain,
        address consumer,
        address borrower,
        uint8 rating,
        uint256 nonce,
        uint64 timestamp
    );

    // ============ Errors ============
    error Unauthorized();
    error InvalidAddress();
    error UnallowedDomain();
    error InvalidRating();

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyAuthorizedRater() {
        if (!authorizedRaters[msg.sender]) revert Unauthorized();
        _;
    }

    // ============ Constructor ============
    constructor(address _mailbox, address _igp, uint32 _domain) {
        mailbox = IMailbox(_mailbox);
        igp = IInterchainGasPaymaster(_igp);
        allowedDomains[_domain] = true;
        owner = msg.sender;
    }

    // ============ Admin ============
    function setDomain(uint32 domain, bool allowed) external onlyOwner {
        allowedDomains[domain] = allowed;
    }

    function setConsumer(uint32 domain, address consumer) external onlyOwner {
        ratingConsumerAddrs[domain] = consumer;
    }

    function setRater(address rater, bool allowed) external onlyOwner {
        authorizedRaters[rater] = allowed;
    }

    // ============ Dispatch Rating ============
    function dispatchRating(
        uint32 domain,
        address borrower,
        uint8 rating,
        uint256 gasLimit
    ) external payable onlyAuthorizedRater returns (bytes32 messageId) {
        if (!allowedDomains[domain]) revert UnallowedDomain();
        if (rating > 100) revert InvalidRating();
        if (borrower == address(0)) revert InvalidAddress();

        uint64 timestamp = uint64(block.timestamp);
        uint256 nonce = borrowersNonce[borrower];

        bytes memory message = abi.encode(borrower, rating, timestamp, nonce);

        messageId = mailbox.dispatch{value: msg.value}(
            domain,
            addressToBytes32(ratingConsumerAddrs[domain]),
            message
        );

        igp.payForGas{value: msg.value}(
            messageId,
            domain,
            gasLimit,
            msg.sender
        );

        borrowersNonce[borrower] = nonce + 1;

        emit RatingDispatched(
            messageId,
            domain,
            ratingConsumerAddrs[domain],
            borrower,
            rating,
            nonce,
            timestamp
        );
    }

    function addressToBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }
}
