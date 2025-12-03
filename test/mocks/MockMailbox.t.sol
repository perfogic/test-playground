// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IMailbox, IInterchainSecurityModule, IPostDispatchHook} from "../../src/interfaces/IMailbox.sol";
import {IInterchainGasPaymaster} from "../../src/interfaces/IInterchainGasPaymaster.sol";
import {RatingSender} from "../../src/RatingSender.sol";
import {RatingConsumer} from "../../src/RatingConsumer.sol";
import {IHyperlaneRecipient} from "./IHyperlaneRecipient.sol";

contract MockMailbox_E2E is IMailbox {
    uint32 public local;
    uint32 public nextNonce = 1;

    // storage for last dispatched message (source side)
    bytes32 public lastId;
    bytes public lastBody;
    bytes32 public lastRecipient;
    uint32 public lastDest;
    address public lastSender;

    // Destination-side wiring: call handle() on the recipient when process() is invoked
    constructor(uint32 _local) {
        local = _local;
    }

    function localDomain() external view returns (uint32) {
        return local;
    }

    function delivered(bytes32) external pure returns (bool) {
        return true;
    }

    function defaultIsm() external pure returns (IInterchainSecurityModule) {
        return IInterchainSecurityModule(address(0));
    }

    function defaultHook() external pure returns (IPostDispatchHook) {
        return IPostDispatchHook(address(0));
    }

    function requiredHook() external pure returns (IPostDispatchHook) {
        return IPostDispatchHook(address(0));
    }

    function latestDispatchedId() external view returns (bytes32) {
        return lastId;
    }

    function nonce() external view returns (uint32) {
        return nextNonce;
    }

    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody
    ) external payable returns (bytes32 messageId) {
        lastSender = msg.sender;
        lastDest = destinationDomain;
        lastRecipient = recipientAddress;
        lastBody = messageBody;
        messageId = keccak256(
            abi.encodePacked(
                block.chainid,
                address(this),
                nextNonce,
                msg.sender,
                destinationDomain,
                recipientAddress,
                messageBody
            )
        );
        lastId = messageId;
        nextNonce++;
        emit Dispatch(
            msg.sender,
            destinationDomain,
            recipientAddress,
            messageBody
        );
        emit DispatchId(messageId);
    }

    // Overloads (not used)
    function quoteDispatch(
        uint32,
        bytes32,
        bytes calldata
    ) external pure returns (uint256) {
        return 0;
    }

    function dispatch(
        uint32 d,
        bytes32 r,
        bytes calldata b,
        bytes calldata
    ) external payable returns (bytes32) {
        return this.dispatch(d, r, b);
    }

    function quoteDispatch(
        uint32,
        bytes32,
        bytes calldata,
        bytes calldata
    ) external pure returns (uint256) {
        return 0;
    }

    function dispatch(
        uint32 d,
        bytes32 r,
        bytes calldata b,
        bytes calldata,
        IPostDispatchHook
    ) external payable returns (bytes32) {
        return this.dispatch(d, r, b);
    }

    function quoteDispatch(
        uint32,
        bytes32,
        bytes calldata,
        bytes calldata,
        IPostDispatchHook
    ) external pure returns (uint256) {
        return 0;
    }

    // In E2E, the relayer calls process() on the destination mailbox,
    // and this mailbox forwards to recipient.handle(origin, sender, body)
    function process(
        bytes calldata metadata,
        bytes calldata message
    ) external payable {
        // For simplicity, metadata = abi.encode(uint32 origin, bytes32 sender)
        // message = abi.encode(address recipient, bytes body)
        (uint32 origin, bytes32 sender) = abi.decode(
            metadata,
            (uint32, bytes32)
        );
        (address recipient, bytes memory body) = abi.decode(
            message,
            (address, bytes)
        );

        emit ProcessId(
            bytes32(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            block.number,
                            origin,
                            sender,
                            recipient
                        )
                    )
                )
            )
        );
        emit Process(origin, sender, recipient);

        // Call recipient (onlyMailbox enforces msg.sender == this)
        IHyperlaneRecipient(address(recipient)).handle(origin, sender, body);
    }

    function recipientIsm(
        address
    ) external pure returns (IInterchainSecurityModule) {
        return IInterchainSecurityModule(address(0));
    }
}
