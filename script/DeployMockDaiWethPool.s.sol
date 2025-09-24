// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {BaseDeployer} from "./BaseDeployer.s.sol";
import {MockDaiWethPool} from "../src/tests/Defi/MockDaiWethPool.sol";
import {console} from "forge-std/console.sol";

contract DeployMockDaiWethPool is BaseDeployer {
    function run() external {
        uint256 deployerPrivateKey = _getPrivateKey();
        bytes32 _salt = _generateSalt();
        address callBreaker = vm.envAddress("CALL_BREAKER_ADDRESS");
        address dai = vm.envAddress("DAI_ADDRESS");
        address weth = vm.envAddress("WETH_ADDRESS");
        _deploy(_salt, deployerPrivateKey, callBreaker, dai, weth);
    }

    function run(uint256 salt) external {
        uint256 deployerPrivateKey = _getPrivateKey();
        address callBreaker = vm.envAddress("CALL_BREAKER_ADDRESS");
        address dai = vm.envAddress("DAI_ADDRESS");
        address weth = vm.envAddress("WETH_ADDRESS");
        bytes32 _salt = bytes32(salt);
        _deploy(_salt, deployerPrivateKey, callBreaker, dai, weth);
    }

    function _deploy(bytes32 salt, uint256 deployerPrivateKey, address callBreaker, address dai, address weth)
        internal
    {
        for (uint256 i = 0; i < networks.length; i++) {
            NetworkConfig memory config = networks[i];
            console.log("Deploying MockDaiWethPool to:", config.name);

            vm.createSelectFork(config.rpcUrl);
            vm.startBroadcast(deployerPrivateKey);

            address contractAddress = address(new MockDaiWethPool{salt: salt}(callBreaker, dai, weth));
            address computedAddress = _computeCreate2Address(
                salt,
                hashInitCode(abi.encodePacked(type(MockDaiWethPool).creationCode, abi.encode(callBreaker, dai, weth)))
            );
            require(contractAddress == computedAddress, "Contract address mismatch");
            console.log("MockDaiWethPool deployed to:", contractAddress);

            vm.stopBroadcast();
        }
    }
}
