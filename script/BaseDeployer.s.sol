// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

abstract contract BaseDeployer is Script {
    struct RawNetworkConfig {
        string apiKeyEnv;
        uint256 chainId;
        string explorerUrl;
        string name;
        string rpcEnvKey;
        string verifier;
        string verifierUrl;
    }

    struct RawNetworkConfigWrapper {
        RawNetworkConfig lestnet;
        RawNetworkConfig[] mainnet;
        RawNetworkConfig[] testnet;
    }

    struct NetworkConfig {
        string name;
        string rpcUrl;
        uint256 chainId;
        string verifier;
        string verifierUrl;
        string explorerUrl;
        string apiKey;
    }

    NetworkConfig[] public networks;
    string public networkType;

    constructor() {
        networkType = vm.envString("NETWORK_TYPE");
        _loadNetworks();
        _validateNetworks();
    }

    function _loadNetworks() internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/config/networks.json");
        string memory json = vm.readFile(path);
        bytes memory networksData = vm.parseJson(json);
        RawNetworkConfigWrapper memory wrapper = abi.decode(
            networksData,
            (RawNetworkConfigWrapper)
        );

        delete networks;

        // Handle different network types
        bytes32 networkTypeHash = keccak256(abi.encodePacked(networkType));

        if (networkTypeHash == keccak256(abi.encodePacked("MAINNET"))) {
            _processNetworkArray(wrapper.mainnet);
        } else if (networkTypeHash == keccak256(abi.encodePacked("TESTNET"))) {
            _processNetworkArray(wrapper.testnet);
        } else if (networkTypeHash == keccak256(abi.encodePacked("LESTNET"))) {
            _processSingleNetwork(wrapper.lestnet);
        } else {
            revert("Unsupported network type");
        }
    }

    function _processNetworkArray(
        RawNetworkConfig[] memory rawConfigs
    ) internal {
        for (uint i = 0; i < rawConfigs.length; i++) {
            NetworkConfig memory config = NetworkConfig({
                name: rawConfigs[i].name,
                rpcUrl: vm.envString(rawConfigs[i].rpcEnvKey),
                chainId: rawConfigs[i].chainId,
                verifier: rawConfigs[i].verifier,
                verifierUrl: rawConfigs[i].verifierUrl,
                explorerUrl: rawConfigs[i].explorerUrl,
                apiKey: vm.envString(rawConfigs[i].apiKeyEnv)
            });
            networks.push(config);
        }
    }

    function _processSingleNetwork(RawNetworkConfig memory rawConfig) internal {
        NetworkConfig memory config = NetworkConfig({
            name: rawConfig.name,
            rpcUrl: vm.envString(rawConfig.rpcEnvKey),
            chainId: rawConfig.chainId,
            verifier: rawConfig.verifier,
            verifierUrl: rawConfig.verifierUrl,
            explorerUrl: rawConfig.explorerUrl,
            apiKey: vm.envString(rawConfig.apiKeyEnv)
        });
        networks.push(config);
    }

    function _validateNetworks() internal view {
        require(networks.length > 0, "No networks configured for this type");
    }

    function _getPrivateKey() internal view returns (uint256) {
        string memory envVar = string(
            abi.encodePacked(networkType, "_PRIVATE_KEY")
        );
        return vm.envUint(envVar);
    }

    function _computeCreate2Address(bytes32 salt, bytes32 creationCode) internal pure returns (address) {
        return computeCreate2Address(salt, creationCode);    
    }
}
