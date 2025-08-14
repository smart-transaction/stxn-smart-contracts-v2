// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {MockERC20} from "../mock/MockERC20.sol";

// Re-export MockERC20 as MockERC20Token for backward compatibility
contract MockERC20Token is MockERC20 {
    constructor(string memory name, string memory symbol) MockERC20(name, symbol) {}
}
