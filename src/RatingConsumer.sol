// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IMessageRecipient.sol";
import "./interfaces/IMailbox.sol";

contract RatingConsumer is IMessageRecipient {
    // ============ Structs ============
    struct BorrowerRating {
        uint8 rating;
        uint64 timestamp;
        uint256 nonce;
    }

    // ============ State ============
    uint32 public immutable domain; // origin chain domain
    address public authorizedSender; // RatingSender on Ethereum
    IMailbox public immutable mailbox;
    uint256 public immutable MAX_AGE;
    address public owner;

    mapping(address => BorrowerRating) public borrowerRatings;

    // ============ Events ============
    event RatingUpdated(
        address borrower,
        uint8 rating,
        uint64 ts,
        uint256 nonce
    );

    // ============ Errors ============
    error UnauthorizedMailbox();
    error UnauthorizedOrigin();
    error UnauthorizedSender();
    error NotOwner();
    error StaleRating();
    error InvalidRating();
    error ReplayAttempt();

    // ============ Constructor ============
    constructor(
        address _mailbox,
        uint32 _originDomain,
        address _authorizedSender,
        uint256 _maxAge
    ) {
        mailbox = IMailbox(_mailbox);
        domain = _originDomain;
        authorizedSender = _authorizedSender;
        MAX_AGE = _maxAge;
        owner = msg.sender;
    }

    // ============ Modifiers ============
    modifier onlyMailbox() {
        if (msg.sender != address(mailbox)) revert UnauthorizedMailbox();
        _;
    }

    // ============ Handle ============
    function handle(
        uint32 origin,
        bytes32 sender,
        bytes calldata messageBody
    ) external payable override onlyMailbox {
        if (origin != domain) revert UnauthorizedOrigin();
        if (sender != addressToBytes32(authorizedSender))
            revert UnauthorizedSender();

        (address borrower, uint8 rating, uint64 timestamp, uint256 nonce) = abi
            .decode(messageBody, (address, uint8, uint64, uint256));

        if (block.timestamp > timestamp + MAX_AGE) revert StaleRating();

        BorrowerRating storage stored = borrowerRatings[borrower];

        if (timestamp <= stored.timestamp) revert InvalidRating();
        if (nonce <= stored.nonce && nonce - stored.nonce == 1)
            revert ReplayAttempt();

        stored.rating = rating;
        stored.timestamp = timestamp;
        stored.nonce = nonce;

        emit RatingUpdated(borrower, rating, timestamp, nonce);
    }

    // ============ Get LTV ============
    function getBorrowerLTV(address borrower) external view returns (uint16) {
        BorrowerRating memory r = borrowerRatings[borrower];

        // No rating → safe fallback
        if (r.timestamp == 0) return 4000;

        if (block.timestamp > r.timestamp + MAX_AGE) return 4000;
        if (r.rating >= 80) return 7500;
        if (r.rating >= 50) return 6000;

        return 4000;
    }

    function getBorrowerRating(
        address borrower
    ) external view returns (uint8, uint256, uint64) {
        BorrowerRating memory r = borrowerRatings[borrower];
        return (r.rating, r.nonce, r.timestamp);
    }

    function setOwner(address newOwner) external {
        if (msg.sender != owner) revert NotOwner();
        owner = newOwner;
    }

    function addressToBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }
}
