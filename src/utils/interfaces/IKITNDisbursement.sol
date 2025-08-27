// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

/// @dev Struct for holding disbursal data details
struct DisbursalData {
    /// @notice The addresses going to receive KITN Token
    address[] receivers;
    /// @notice The amount of KITN Token to be received
    uint256[] amounts;
}

interface IKITNDisbursement {
    function disburseTokens() external;
}
