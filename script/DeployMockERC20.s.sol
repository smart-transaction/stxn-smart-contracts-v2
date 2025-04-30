// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BaseDeployer} from "./BaseDeployer.s.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import {console} from "forge-std/console.sol";

contract DeployMockERC20 is BaseDeployer {
    function run(string memory name, string memory symbol) external {
        uint256 deployerPrivateKey = _getPrivateKey();
        bytes32 _salt = _generateSalt();
        _deploy(_salt, deployerPrivateKey, name, symbol);
    }

    function run(uint256 salt, string memory name, string memory symbol) external {
        uint256 deployerPrivateKey = _getPrivateKey();
        bytes32 _salt = bytes32(salt);
        _deploy(_salt, deployerPrivateKey, name, symbol);
    }

    function _deploy(bytes32 salt, uint256 deployerPrivateKey, string memory name, string memory symbol) internal {
        for (uint256 i = 0; i < networks.length; i++) {
            NetworkConfig memory config = networks[i];
            console.log("Deploying MockERC20 to:", config.name);

            vm.createSelectFork(config.rpcUrl);
            vm.startBroadcast(deployerPrivateKey);

            address contractAddress = address(new MockERC20{salt: salt}(name, symbol));
            address computedAddress = _computeCreate2Address(salt, hashInitCode(type(MockERC20).creationCode, abi.encode(name, symbol)));
            require(contractAddress == computedAddress, "Contract address mismatch");
            console.log("MockERC20 deployed to:", contractAddress);

            vm.stopBroadcast();
        }
    }
}
