// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

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

    function mintTokens(address mockERC20, address[] calldata users) external {
        uint256 deployerPrivateKey = _getPrivateKey();

        for (uint256 i = 0; i < networks.length; i++) {
            NetworkConfig memory config = networks[i];
            console.log("Minting on network:", config.name);

            vm.createSelectFork(config.rpcUrl);
            vm.startBroadcast(deployerPrivateKey);

            MockERC20 token = MockERC20(mockERC20);
            uint256 totalMinted = 0;

            // Get token decimals and calculate base unit
            uint8 decimals = token.decimals();
            uint256 decimalsMultiplier = 10 ** decimals;

            for (uint256 j = 0; j < users.length; j++) {
                // Generate random amount between 1000 and 100000 token units
                uint256 minAmount = 1000 * decimalsMultiplier;
                uint256 maxAmount = 100000 * decimalsMultiplier;
                uint256 amount = minAmount + (vm.randomUint() % (maxAmount - minAmount));

                token.mint(users[j], amount);
                totalMinted += amount;

                console.log("Minted %s (10^%d) tokens to %s", amount / decimalsMultiplier, decimals, users[j]);
            }

            vm.stopBroadcast();
            console.log("Total minted on %s: %s base units", config.name, totalMinted);
        }
    }

    function _deploy(bytes32 salt, uint256 deployerPrivateKey, string memory name, string memory symbol) internal {
        for (uint256 i = 0; i < networks.length; i++) {
            NetworkConfig memory config = networks[i];
            console.log("Deploying MockERC20 to:", config.name);

            vm.createSelectFork(config.rpcUrl);
            vm.startBroadcast(deployerPrivateKey);

            address contractAddress = address(new MockERC20{salt: salt}(name, symbol));
            address computedAddress =
                _computeCreate2Address(salt, hashInitCode(type(MockERC20).creationCode, abi.encode(name, symbol)));
            require(contractAddress == computedAddress, "Contract address mismatch");
            console.log("MockERC20 deployed to:", contractAddress);

            vm.stopBroadcast();
        }
    }
}
