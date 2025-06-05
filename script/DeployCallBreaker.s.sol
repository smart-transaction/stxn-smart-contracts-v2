// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BaseDeployer} from "./BaseDeployer.s.sol";
import {CallBreaker} from "../src/CallBreaker.sol";
import {console} from "forge-std/console.sol";

contract DeployCallBreaker is BaseDeployer {
    function run() external {
        uint256 deployerPrivateKey = _getPrivateKey();
        bytes32 _salt = _generateSalt();
        address owner = _getOwner();
        _deploy(_salt, deployerPrivateKey, owner);
    }

    function run(uint256 salt) external {
        uint256 deployerPrivateKey = _getPrivateKey();
        address owner = _getOwner();
        bytes32 _salt = bytes32(salt);
        _deploy(_salt, deployerPrivateKey, owner);
    }

    function _deploy(bytes32 salt, uint256 deployerPrivateKey, address owner) internal {
        for (uint256 i = 0; i < networks.length; i++) {
            NetworkConfig memory config = networks[i];
            console.log("Deploying CallBreaker to:", config.name);

            vm.createSelectFork(config.rpcUrl);
            vm.startBroadcast(deployerPrivateKey);

            address contractAddress = address(new CallBreaker{salt: salt}(owner));
            address computedAddress = _computeCreate2Address(
                salt, hashInitCode(abi.encodePacked(type(CallBreaker).creationCode, abi.encode(owner)))
            );
            require(contractAddress == computedAddress, "Contract address mismatch");
            console.log("CallBreaker deployed to:", contractAddress);

            vm.stopBroadcast();
        }
    }
}
