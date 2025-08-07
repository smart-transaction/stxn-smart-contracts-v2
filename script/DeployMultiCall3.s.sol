// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {BaseDeployer} from "./BaseDeployer.s.sol";
import {MultiCall3} from "../src/utils/MultiCall3.sol";
import {console} from "forge-std/console.sol";

contract DeployMultiCall3 is BaseDeployer {
    function run() external {
        uint256 deployerPrivateKey = _getPrivateKey();
        bytes32 _salt = _generateSalt();
        _deploy(_salt, deployerPrivateKey);
    }

    function run(uint256 salt) external {
        uint256 deployerPrivateKey = _getPrivateKey();
        bytes32 _salt = bytes32(salt);
        _deploy(_salt, deployerPrivateKey);
    }

    function _deploy(bytes32 salt, uint256 deployerPrivateKey) internal {
        for (uint256 i = 0; i < networks.length; i++) {
            NetworkConfig memory config = networks[i];
            console.log("Deploying MultiCall3 to:", config.name);

            vm.createSelectFork(config.rpcUrl);
            vm.startBroadcast(deployerPrivateKey);

            address contractAddress = address(new MultiCall3{salt: salt}());
            address computedAddress = _computeCreate2Address(salt, hashInitCode(type(MultiCall3).creationCode));
            require(contractAddress == computedAddress, "Contract address mismatch");
            console.log("MultiCall3 deployed to:", contractAddress);

            vm.stopBroadcast();
        }
    }
}
