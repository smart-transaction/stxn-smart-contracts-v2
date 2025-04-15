// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title Multicall Interface
/// @notice Interface for batch contract execution functionality
interface IMulticall {
    /// @notice Call specification structure
    /// @param target Contract address to call
    /// @param callData Calldata to send to target
    struct Call {
        address target;
        bytes callData;
    }

    /// @notice Call result structure
    /// @param success Boolean success status
    /// @param returnData Returned bytes data
    struct Result {
        bool success;
        bytes returnData;
    }

    /// @notice Execute multiple calls atomically
    /// @dev Continues execution after individual call failures
    /// @param calls Array of Call structures to execute
    /// @return results Array of Result structures
    function aggregate(Call[] calldata calls)
        external
        payable
        returns (
            Result[] memory results
        );
}