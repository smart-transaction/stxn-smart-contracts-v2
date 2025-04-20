// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BaseDeployer} from "./BaseDeployer.s.sol";
import {CallBreaker} from "../src/CallBreaker.sol";
import {console} from "forge-std/console.sol";

contract DeployCallBreaker is BaseDeployer {
    function run() external {
        uint256 deployerPrivateKey = _getPrivateKey();

        for (uint i = 0; i < networks.length; i++) {
            NetworkConfig memory config = networks[i];
            console.log("Deploying CallBreaker to:", config.name);

            vm.createSelectFork(config.rpcUrl);
            vm.startBroadcast(deployerPrivateKey);

            address contractAddress = address(new CallBreaker());
            console.log("CallBreaker deployed to:", contractAddress);

            vm.stopBroadcast();
        }
    }
}
