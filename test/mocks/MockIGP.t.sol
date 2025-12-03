// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IInterchainGasPaymaster} from "../../src/interfaces/IInterchainGasPaymaster.sol";

contract MockIGP_E2E is IInterchainGasPaymaster {
    uint256 public pricePerGas;
    mapping(bytes32 => uint256) public paid;

    constructor(uint256 _ppg) {
        pricePerGas = _ppg;
    }

    function payForGas(
        bytes32 id,
        uint32 d,
        uint256 g,
        address
    ) external payable {
        require(msg.value == g * pricePerGas, "bad fee");
        paid[id] = msg.value;
        emit GasPayment(id, d, g, msg.value);
    }

    function quoteGasPayment(
        uint32,
        uint256 g
    ) external view returns (uint256) {
        return g * pricePerGas;
    }
}
