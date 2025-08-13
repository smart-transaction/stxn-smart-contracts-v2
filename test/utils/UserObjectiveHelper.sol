// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

import {CallObject, UserObjective} from "src/interfaces/ICallBreaker.sol";

/// @title UserObjectiveHelper
/// @notice Helper library for creating UserObjective structs in tests
library UserObjectiveHelper {
    /// @notice Default app ID used in tests
    bytes public constant DEFAULT_APP_ID = hex"01";

    /// @notice Default tip amount
    uint256 public constant DEFAULT_TIP = 0;

    /// @notice Default max fee per gas
    uint256 public constant DEFAULT_MAX_FEE_PER_GAS = 1 gwei;

    /// @notice Default max priority fee per gas
    uint256 public constant DEFAULT_MAX_PRIORITY_FEE_PER_GAS = 1 gwei;

    /// @notice Default chain ID (Ethereum mainnet)
    uint256 public constant DEFAULT_CHAIN_ID = 1;

    /// @notice Builds a UserObjective with default values for the current chain
    /// @param nonce The nonce for the user objective
    /// @param sender The sender address
    /// @param callObjs Array of call objects
    /// @return The constructed UserObjective
    function buildUserObjective(uint256 nonce, address sender, CallObject[] memory callObjs)
        internal
        pure
        returns (UserObjective memory)
    {
        return UserObjective({
            appId: DEFAULT_APP_ID,
            nonce: nonce,
            tip: DEFAULT_TIP,
            chainId: DEFAULT_CHAIN_ID,
            maxFeePerGas: DEFAULT_MAX_FEE_PER_GAS,
            maxPriorityFeePerGas: DEFAULT_MAX_PRIORITY_FEE_PER_GAS,
            sender: sender,
            callObjects: callObjs
        });
    }

    /// @notice Builds a UserObjective for a specific chain
    /// @param chainId The chain ID
    /// @param nonce The nonce for the user objective
    /// @param sender The sender address
    /// @param callObjs Array of call objects
    /// @return The constructed UserObjective
    function buildCrossChainUserObjective(uint256 chainId, uint256 nonce, address sender, CallObject[] memory callObjs)
        internal
        pure
        returns (UserObjective memory)
    {
        return UserObjective({
            appId: DEFAULT_APP_ID,
            nonce: nonce,
            tip: DEFAULT_TIP,
            chainId: chainId,
            maxFeePerGas: DEFAULT_MAX_FEE_PER_GAS,
            maxPriorityFeePerGas: DEFAULT_MAX_PRIORITY_FEE_PER_GAS,
            sender: sender,
            callObjects: callObjs
        });
    }

    /// @notice Builds a UserObjective with custom gas settings
    /// @param nonce The nonce for the user objective
    /// @param sender The sender address
    /// @param callObjs Array of call objects
    /// @param maxFeePerGas Custom max fee per gas
    /// @param maxPriorityFeePerGas Custom max priority fee per gas
    /// @return The constructed UserObjective
    function buildUserObjectiveWithCustomGas(
        uint256 nonce,
        address sender,
        CallObject[] memory callObjs,
        uint256 maxFeePerGas,
        uint256 maxPriorityFeePerGas
    ) internal pure returns (UserObjective memory) {
        return UserObjective({
            appId: DEFAULT_APP_ID,
            nonce: nonce,
            tip: DEFAULT_TIP,
            chainId: DEFAULT_CHAIN_ID,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            sender: sender,
            callObjects: callObjs
        });
    }

    /// @notice Builds a UserObjective with custom tip
    /// @param nonce The nonce for the user objective
    /// @param sender The sender address
    /// @param callObjs Array of call objects
    /// @param tip Custom tip amount
    /// @return The constructed UserObjective
    function buildUserObjectiveWithTip(uint256 nonce, address sender, CallObject[] memory callObjs, uint256 tip)
        internal
        pure
        returns (UserObjective memory)
    {
        return UserObjective({
            appId: DEFAULT_APP_ID,
            nonce: nonce,
            tip: tip,
            chainId: DEFAULT_CHAIN_ID,
            maxFeePerGas: DEFAULT_MAX_FEE_PER_GAS,
            maxPriorityFeePerGas: DEFAULT_MAX_PRIORITY_FEE_PER_GAS,
            sender: sender,
            callObjects: callObjs
        });
    }

    /// @notice Builds a UserObjective with custom app ID
    /// @param appId Custom app ID
    /// @param nonce The nonce for the user objective
    /// @param sender The sender address
    /// @param callObjs Array of call objects
    /// @return The constructed UserObjective
    function buildUserObjectiveWithAppId(
        bytes memory appId,
        uint256 nonce,
        address sender,
        CallObject[] memory callObjs
    ) internal pure returns (UserObjective memory) {
        return UserObjective({
            appId: appId,
            nonce: nonce,
            tip: DEFAULT_TIP,
            chainId: DEFAULT_CHAIN_ID,
            maxFeePerGas: DEFAULT_MAX_FEE_PER_GAS,
            maxPriorityFeePerGas: DEFAULT_MAX_PRIORITY_FEE_PER_GAS,
            sender: sender,
            callObjects: callObjs
        });
    }

    /// @notice Builds a UserObjective with all custom parameters
    /// @param appId Custom app ID
    /// @param nonce The nonce for the user objective
    /// @param tip Custom tip amount
    /// @param chainId Custom chain ID
    /// @param maxFeePerGas Custom max fee per gas
    /// @param maxPriorityFeePerGas Custom max priority fee per gas
    /// @param sender The sender address
    /// @param callObjs Array of call objects
    /// @return The constructed UserObjective
    function buildUserObjectiveWithAllParams(
        bytes memory appId,
        uint256 nonce,
        uint256 tip,
        uint256 chainId,
        uint256 maxFeePerGas,
        uint256 maxPriorityFeePerGas,
        address sender,
        CallObject[] memory callObjs
    ) internal pure returns (UserObjective memory) {
        return UserObjective({
            appId: appId,
            nonce: nonce,
            tip: tip,
            chainId: chainId,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            sender: sender,
            callObjects: callObjs
        });
    }

    /// @notice Builds a UserObjective with high gas fees to test insufficient balance scenarios
    /// @param nonce The nonce for the user objective
    /// @param sender The sender address
    /// @param callObjs Array of call objects
    /// @return The constructed UserObjective
    function buildUserObjectiveWithInsufficientBalance(uint256 nonce, address sender, CallObject[] memory callObjs)
        internal
        pure
        returns (UserObjective memory)
    {
        return UserObjective({
            appId: DEFAULT_APP_ID,
            nonce: nonce,
            tip: DEFAULT_TIP,
            chainId: DEFAULT_CHAIN_ID,
            maxFeePerGas: 500_000 gwei,
            maxPriorityFeePerGas: 500_000 gwei,
            sender: sender,
            callObjects: callObjs
        });
    }
}
