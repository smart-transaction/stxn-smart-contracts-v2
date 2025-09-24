// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

/// @dev Struct for holding call object details
struct CallObject {
    /// @notice Random value to ensure uniqueness of the call object
    uint256 salt;
    /// @notice Amount of ETH to be sent with the call
    uint256 amount;
    /// @notice Gas limit for this call
    uint256 gas;
    /// @notice Target contract address to call
    address addr;
    /// @notice Calldata to be sent with the call
    bytes callvalue;
    /// @notice Expected return value from the call
    bytes returnvalue;
    /// @notice Whether this call can be skipped by the solver // TODO
    bool skippable;
    /// @notice Whether return value should be verified
    bool verifiable;
    /// @notice Whether to expose return value for use by other calls
    bool exposeReturn;
}

/// @dev Struct for holding a sequence of call objects and their return values pushed by the user
struct UserObjective {
    /// @notice App Id associated to an application to allow solvers to pick relevant objectives
    bytes appId;
    /// @notice Nonce to prevent replay attacks
    uint256 nonce;
    /// @notice Tip amount to be paid to the solver
    uint256 tip;
    /// @notice Chain ID where this call should be executed
    uint256 chainId;
    /// @notice Maximum fee per gas the user is willing to pay for this transaction
    uint256 maxFeePerGas;
    /// @notice Maximum priority fee per gas the user is willing to pay for this transaction
    uint256 maxPriorityFeePerGas;
    /// @notice Address of the user who submitted this objective
    address sender;
    /// @notice Signature of user objective
    bytes signature;
    /// @notice Array of call objects to be executed for this user
    CallObject[] callObjects;
}

struct AdditionalData {
    bytes32 key;
    bytes value;
}

interface ISmartExecute {
    function pushUserObjective(UserObjective calldata _userObjective, AdditionalData[] calldata _additionalData)
        external
        payable
        returns (bytes32 requestId);
}
