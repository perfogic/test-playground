// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RatingSender} from "../src/RatingSender.sol";
import {RatingConsumer} from "../src/RatingConsumer.sol";
import {MockMailbox_E2E} from "./mocks/MockMailbox.t.sol";
import {MockIGP_E2E} from "./mocks/MockIGP.t.sol";

contract E2E_Crosschain_Test is Test {
    uint32 constant ETH_DOMAIN = 1;
    uint32 constant ARB_DOMAIN = 42161;
    uint256 constant MAX_AGE = 2 hours;

    MockMailbox_E2E ethereumMailbox;
    MockMailbox_E2E arbitrumMailbox;
    MockIGP_E2E e2eIgp;
    RatingSender ratingSender;
    RatingConsumer ratingConsumer;

    address contractOwner = address(0xABCD);
    address authorizedRater = address(0xAAAA);
    address trustedRelayer = address(0xABF4);

    function setUp() public {
        vm.startPrank(contractOwner);
        ethereumMailbox = new MockMailbox_E2E(ETH_DOMAIN);
        arbitrumMailbox = new MockMailbox_E2E(ARB_DOMAIN);
        e2eIgp = new MockIGP_E2E(2 gwei);
        ratingSender = new RatingSender(
            address(ethereumMailbox),
            address(e2eIgp),
            ARB_DOMAIN
        );
        ratingConsumer = new RatingConsumer(
            address(arbitrumMailbox),
            ETH_DOMAIN,
            address(ratingSender),
            MAX_AGE
        );
        ratingSender.setConsumer(ARB_DOMAIN, address(ratingConsumer));
        ratingSender.setRater(authorizedRater, true);
        vm.stopPrank();
    }

    function test_E2E_DispatchThenDeliver_UpdatesConsumer() public {
        address borrower = address(0xBEEF);

        vm.prank(authorizedRater);
        ratingSender.dispatchRating(ARB_DOMAIN, borrower, uint8(88), 0);

        bytes memory meta = abi.encode(
            ETH_DOMAIN,
            bytes32(uint256(uint160(address(ratingSender))))
        );
        bytes memory msgBody = abi.encode(
            address(ratingConsumer),
            ethereumMailbox.lastBody()
        );

        vm.prank(trustedRelayer);
        arbitrumMailbox.process(meta, msgBody);

        (uint8 score, uint256 nonce, uint64 ts) = ratingConsumer.getBorrowerRating(
            borrower
        );
        assertEq(score, 88);
        assertEq(nonce, 0);
        assertGt(ts, 0);
        assertEq(ratingConsumer.getBorrowerLTV(borrower), 7500);
    }

    function test_E2E_Deliver_RevertsOnStaleMessage() public {
        address borrower = address(0xDEAD);
        uint8 rating = 40;
        vm.warp(block.timestamp + MAX_AGE + 5);
        uint64 oldTs = uint64(block.timestamp - MAX_AGE - 1);
        bytes memory body = abi.encode(borrower, rating, oldTs, uint64(0));

        bytes memory meta = abi.encode(
            ETH_DOMAIN,
            bytes32(uint256(uint160(address(ratingSender))))
        );
        bytes memory msgBody = abi.encode(address(ratingConsumer), body);

        vm.expectRevert(RatingConsumer.StaleRating.selector);
        vm.prank(trustedRelayer);
        arbitrumMailbox.process(meta, msgBody);
    }

    function test_E2E_Deliver_RevertsOnWrongOrigin() public {
        address borrower = address(0xB011);

        vm.prank(authorizedRater);
        ratingSender.dispatchRating(ARB_DOMAIN, borrower, uint8(70), 0);

        bytes memory badMeta = abi.encode(
            ETH_DOMAIN + 1,
            bytes32(uint256(uint160(address(ratingSender))))
        );
        bytes memory msgBody = abi.encode(
            address(ratingConsumer),
            ethereumMailbox.lastBody()
        );

        vm.expectRevert(RatingConsumer.UnauthorizedOrigin.selector);
        vm.prank(trustedRelayer);
        arbitrumMailbox.process(badMeta, msgBody);
    }

    function test_E2E_Deliver_RevertsOnWrongSender() public {
        address borrower = address(0xB022);

        vm.prank(authorizedRater);
        ratingSender.dispatchRating(ARB_DOMAIN, borrower, uint8(65), 0);

        bytes memory badMeta = abi.encode(
            ETH_DOMAIN,
            bytes32(uint256(uint160(address(0xDEAD))))
        );
        bytes memory msgBody = abi.encode(
            address(ratingConsumer),
            ethereumMailbox.lastBody()
        );

        vm.expectRevert(RatingConsumer.UnauthorizedSender.selector);
        vm.prank(trustedRelayer);
        arbitrumMailbox.process(badMeta, msgBody);
    }
}
