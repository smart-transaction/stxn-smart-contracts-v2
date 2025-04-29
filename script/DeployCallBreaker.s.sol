// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BaseDeployer} from "./BaseDeployer.s.sol";
import {CallBreaker} from "../src/CallBreaker.sol";
import {console} from "forge-std/console.sol";

contract DeployCallBreaker is BaseDeployer {
    // Non-salted deployment (CREATE)
    function run() external {
        uint256 deployerPrivateKey = _getPrivateKey();

        for (uint256 i = 0; i < networks.length; i++) {
            NetworkConfig memory config = networks[i];
            console.log("Deploying CallBreaker (CREATE) to:", config.name);

            vm.createSelectFork(config.rpcUrl);
            vm.startBroadcast(deployerPrivateKey);

            address contractAddress = address(new CallBreaker());
            console.log("CallBreaker deployed to:", contractAddress);

            vm.stopBroadcast();
        }
    }

    // Salted deployment (CREATE2)
    function run(uint256 salt) external {
        uint256 deployerPrivateKey = _getPrivateKey();
        bytes32 _salt = bytes32(salt);

        for (uint256 i = 0; i < networks.length; i++) {
            NetworkConfig memory config = networks[i];
            console.log("Deploying CallBreaker (CREATE2) to:", config.name);

            vm.createSelectFork(config.rpcUrl);
            vm.startBroadcast(deployerPrivateKey);

            address contractAddress = address(new CallBreaker{salt: _salt}());
            address computedAddress = _computeCreate2Address(_salt, hashInitCode(type(CallBreaker).creationCode));
            require(contractAddress == computedAddress, "Contract address mismatch");
            console.log("CallBreaker deployed to:", contractAddress);

            vm.stopBroadcast();
        }
    }
}
