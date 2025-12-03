// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RatingSender} from "../src/RatingSender.sol";
import {MockIGP, MockMailbox} from "./mocks/RatingSenderMocks.sol";

contract RatingSender_Test is Test {
    uint32 constant ETH_DOMAIN = 1;
    uint32 constant ARB_DOMAIN = 42161;

    RatingSender ratingSender;
    MockMailbox sourceMailbox;
    MockIGP interchainGasPaymaster;

    address contractOwner = address(0xABCD);
    address authorizedRater = address(0xAAAA);
    address arbConsumer = address(0xADEF);

    function setUp() public {
        sourceMailbox = new MockMailbox(ETH_DOMAIN);
        interchainGasPaymaster = new MockIGP(2 gwei);
        vm.prank(contractOwner);
        ratingSender = new RatingSender(
            address(sourceMailbox),
            address(interchainGasPaymaster),
            ARB_DOMAIN
        );
        vm.prank(contractOwner);
        ratingSender.setConsumer(ARB_DOMAIN, arbConsumer);
        vm.prank(contractOwner);
        ratingSender.setRater(authorizedRater, true);
    }

    function test_DispatchRating_PublishesMessageAndPaysGas() public {
        address borrower = address(0xBEEF);
        uint8 score = 90;
        uint256 destGasLimit = 0;

        vm.prank(authorizedRater);
        bytes32 messageId = ratingSender.dispatchRating(
            ARB_DOMAIN,
            borrower,
            score,
            destGasLimit
        );
        assertTrue(messageId != bytes32(0));
        assertEq(sourceMailbox.lastDest(), ARB_DOMAIN);
        assertEq(
            address(uint160(uint256(sourceMailbox.lastRecipient()))),
            arbConsumer
        );

        (
            address decodedBorrower,
            uint8 decodedScore,
            uint64 timestamp,
            uint256 nonce
        ) = abi.decode(
                sourceMailbox.lastBody(),
                (address, uint8, uint64, uint256)
            );
        assertEq(decodedBorrower, borrower);
        assertEq(decodedScore, score);
        assertEq(nonce, 0);
        assertGt(timestamp, 0);
        assertEq(interchainGasPaymaster.lastDest(), ARB_DOMAIN);
        assertEq(interchainGasPaymaster.lastGas(), destGasLimit);
        assertEq(interchainGasPaymaster.lastRefund(), authorizedRater);
        assertEq(ratingSender.borrowersNonce(borrower), 1);
    }

    function test_DispatchRating_IncrementsBorrowerNonce() public {
        address borrower = address(0xB00B);

        vm.startPrank(authorizedRater);
        ratingSender.dispatchRating(ARB_DOMAIN, borrower, uint8(55), 0);
        ratingSender.dispatchRating(ARB_DOMAIN, borrower, uint8(60), 0);
        vm.stopPrank();

        assertEq(ratingSender.borrowersNonce(borrower), 2);

        // check last dispatched message
        (address decodedBorrower, , , uint256 nonce) = abi.decode(
            sourceMailbox.lastBody(),
            (address, uint8, uint64, uint256)
        );
        assertEq(decodedBorrower, borrower);
        assertEq(nonce, 1);
    }

    function test_DispatchRating_RevertsIfCallerNotAuthorized() public {
        address borrower = address(0xCAFE);
        vm.expectRevert(RatingSender.Unauthorized.selector);
        ratingSender.dispatchRating(ARB_DOMAIN, borrower, uint8(50), 0);
    }

    function test_DispatchRating_RevertsForInvalidInputs() public {
        vm.prank(authorizedRater);
        vm.expectRevert(RatingSender.InvalidRating.selector);
        ratingSender.dispatchRating(ARB_DOMAIN, address(0xBEEF), uint8(101), 0);

        vm.prank(authorizedRater);
        vm.expectRevert(RatingSender.InvalidAddress.selector);
        ratingSender.dispatchRating(ARB_DOMAIN, address(0), uint8(50), 0);
    }

    function test_DispatchRating_RevertsWhenDomainDisabled() public {
        vm.prank(contractOwner);
        ratingSender.setDomain(ARB_DOMAIN, false);

        vm.prank(authorizedRater);
        vm.expectRevert(RatingSender.UnallowedDomain.selector);
        ratingSender.dispatchRating(
            ARB_DOMAIN,
            address(0xC0FFEE),
            uint8(70),
            0
        );
    }

    function test_AdminSetters_RevertForNonOwner() public {
        address notOwner = address(0xB0B);

        vm.prank(notOwner);
        vm.expectRevert(RatingSender.Unauthorized.selector);
        ratingSender.setDomain(ETH_DOMAIN, true);

        vm.prank(notOwner);
        vm.expectRevert(RatingSender.Unauthorized.selector);
        ratingSender.setConsumer(ARB_DOMAIN, address(0x1234));

        vm.prank(notOwner);
        vm.expectRevert(RatingSender.Unauthorized.selector);
        ratingSender.setRater(address(0xCAFE), true);
    }
}
