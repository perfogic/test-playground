// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    IMailbox,
    IInterchainSecurityModule,
    IPostDispatchHook
} from "../../src/interfaces/IMailbox.sol";
import {
    IInterchainGasPaymaster
} from "../../src/interfaces/IInterchainGasPaymaster.sol";

contract MockIGP is IInterchainGasPaymaster {
    uint256 public pricePerGas;
    bytes32 public lastMsgId;
    uint32 public lastDest;
    uint256 public lastGas;
    uint256 public lastPaid;
    address public lastRefund;

    constructor(uint256 _ppg) {
        pricePerGas = _ppg;
    }

    function payForGas(
        bytes32 _messageId,
        uint32 _destinationDomain,
        uint256 _gasAmount,
        address _refundAddress
    ) external payable {
        lastMsgId = _messageId;
        lastDest = _destinationDomain;
        lastGas = _gasAmount;
        lastPaid = msg.value;
        lastRefund = _refundAddress;
        emit GasPayment(_messageId, _destinationDomain, _gasAmount, msg.value);
    }

    function quoteGasPayment(
        uint32,
        uint256 _gasAmount
    ) external view returns (uint256) {
        return _gasAmount * pricePerGas;
    }
}

contract MockMailbox is IMailbox {
    uint32 public local = 0;
    uint32 public nextNonce = 1;
    bytes32 public lastMessageId;
    bytes public lastBody;
    bytes32 public lastRecipient;
    uint32 public lastDest;
    address public lastSender;

    constructor(uint32 _localDomain) {
        local = _localDomain;
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
        return lastMessageId;
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
        lastMessageId = messageId;
        nextNonce++;

        emit Dispatch(
            msg.sender,
            destinationDomain,
            recipientAddress,
            messageBody
        );
        emit DispatchId(messageId);
    }

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

    function process(bytes calldata, bytes calldata) external payable {
        revert("not used here");
    }

    function recipientIsm(
        address
    ) external pure returns (IInterchainSecurityModule) {
        return IInterchainSecurityModule(address(0));
    }
}
