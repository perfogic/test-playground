// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RatingConsumer} from "../src/RatingConsumer.sol";

contract Caller {
    function callHandle(
        address target,
        uint32 o,
        bytes32 s,
        bytes memory m
    ) external {
        RatingConsumer(target).handle(o, s, m);
    }
}

contract RatingConsumer_UnitTest is Test {
    uint32 constant ETH_DOMAIN = 1;
    uint256 constant MAX_AGE = 2 hours;

    RatingConsumer ratingConsumer;
    address originSender = address(0xB0A0);
    bytes32 originSenderBytes32;

    function setUp() public {
        originSenderBytes32 = bytes32(uint256(uint160(originSender)));
        ratingConsumer = new RatingConsumer(
            address(this),
            ETH_DOMAIN,
            originSender,
            MAX_AGE
        );
    }

    function test_GetBorrowerLTV_ReturnsExpectedTier() public {
        address midTierBorrower = address(0xB0B0);
        address lowTierBorrower = address(0xC0C0);

        uint64 ratingTimestamp = uint64(block.timestamp);

        deliverToConsumer(
            ETH_DOMAIN,
            originSenderBytes32,
            abi.encode(midTierBorrower, uint8(50), ratingTimestamp, uint64(1))
        );
        assertEq(ratingConsumer.getBorrowerLTV(midTierBorrower), 6000);

        deliverToConsumer(
            ETH_DOMAIN,
            originSenderBytes32,
            abi.encode(lowTierBorrower, uint8(49), ratingTimestamp, uint64(1))
        );
        assertEq(ratingConsumer.getBorrowerLTV(lowTierBorrower), 4000);
    }

    function test_SetOwner_RevertsWhenCallerNotOwner() public {
        address newOwnerCandidate = address(0xBAD1);
        vm.prank(newOwnerCandidate);
        vm.expectRevert(RatingConsumer.NotOwner.selector);
        ratingConsumer.setOwner(newOwnerCandidate);
    }

    function test_Handle_SetsBorrowerRatingAndComputesLTV() public {
        address borrower = address(0xBEEF);
        uint8 score = 85;
        uint64 ratingTimestamp = uint64(block.timestamp);
        uint256 nonce = 1;

        deliverToConsumer(
            ETH_DOMAIN,
            originSenderBytes32,
            abi.encode(borrower, score, ratingTimestamp, nonce)
        );

        (uint8 gotScore, uint256 gotNonce, uint64 gotTimestamp) = ratingConsumer
            .getBorrowerRating(borrower);
        assertEq(gotScore, score);
        assertEq(gotNonce, nonce);
        assertEq(gotTimestamp, ratingTimestamp);
        assertEq(ratingConsumer.getBorrowerLTV(borrower), 7500);
    }

    function test_Handle_RevertsWhenTimestampNotIncreasing() public {
        address borrower = address(0xCAFE);
        uint64 ratingTimestamp = uint64(block.timestamp);
        bytes memory initialPayload = abi.encode(
            borrower,
            uint8(60),
            ratingTimestamp,
            uint64(1)
        );
        deliverToConsumer(ETH_DOMAIN, originSenderBytes32, initialPayload);

        bytes memory replayPayload = abi.encode(
            borrower,
            uint8(61),
            ratingTimestamp,
            uint64(2)
        );
        vm.expectRevert(RatingConsumer.InvalidRating.selector);
        deliverToConsumer(ETH_DOMAIN, originSenderBytes32, replayPayload);
    }

    function test_Handle_RevertsWhenMessageIsStale() public {
        address borrower = address(0xAAAA);
        vm.warp(block.timestamp + MAX_AGE + 2);
        uint256 oldTs256 = block.timestamp - MAX_AGE - 1;
        assertLt(oldTs256, uint256(type(uint64).max));
        uint64 oldTs = uint64(oldTs256);
        bytes memory payload = abi.encode(
            borrower,
            uint8(40),
            oldTs,
            uint64(1)
        );

        vm.expectRevert(RatingConsumer.StaleRating.selector);
        deliverToConsumer(ETH_DOMAIN, originSenderBytes32, payload);
    }

    function test_Handle_RevertsWhenDomainMismatch() public {
        address borrower = address(0xBBBB);
        uint64 ratingTimestamp = uint64(block.timestamp);
        bytes memory payload = abi.encode(
            borrower,
            uint8(70),
            ratingTimestamp,
            uint64(1)
        );

        vm.expectRevert(RatingConsumer.UnauthorizedOrigin.selector);
        deliverToConsumer(ETH_DOMAIN + 1, originSenderBytes32, payload);
    }

    function test_Handle_RevertsWhenSenderMismatch() public {
        address borrower = address(0xCCCC);
        uint64 ratingTimestamp = uint64(block.timestamp);
        bytes memory payload = abi.encode(
            borrower,
            uint8(70),
            ratingTimestamp,
            uint64(1)
        );

        bytes32 wrongSender = bytes32(uint256(uint160(address(0x1234))));
        vm.expectRevert(RatingConsumer.UnauthorizedSender.selector);
        deliverToConsumer(ETH_DOMAIN, wrongSender, payload);
    }

    function test_Handle_RevertsWhenCallerNotMailbox() public {
        address borrower = address(0xDDDD);
        uint64 ratingTimestamp = uint64(block.timestamp);
        bytes memory payload = abi.encode(
            borrower,
            uint8(55),
            ratingTimestamp,
            uint64(1)
        );

        Caller outsider = new Caller();
        vm.expectRevert(RatingConsumer.UnauthorizedMailbox.selector);
        outsider.callHandle(
            address(ratingConsumer),
            ETH_DOMAIN,
            originSenderBytes32,
            payload
        );
    }

    function test_GetBorrowerLTV_DefaultsWhenNoRating() public view {
        address borrower = address(0xEEEE);
        uint16 ltv = ratingConsumer.getBorrowerLTV(borrower);
        assertEq(ltv, 4000);
    }

    function deliverToConsumer(
        uint32 originDomain,
        bytes32 sender,
        bytes memory payload
    ) internal {
        ratingConsumer.handle(originDomain, sender, payload);
    }
}
