// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IHyperlaneRecipient {
    function handle(uint32, bytes32, bytes calldata) external;
}
