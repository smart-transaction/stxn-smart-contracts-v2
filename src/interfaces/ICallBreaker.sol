// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.28;

/// @dev Struct for holding call object details
struct CallObject {
    uint256 salt;
    uint256 amount;
    uint256 gas;
    address addr;
    bool skippable;
    bool verifiable;
    bytes callvalue;
    bytes returnvalue;
}

/// @dev Struct for holding a sequence of call objects and their return values pushed by the user
struct UserObjective {
    uint256 nonce;
    CallObject[] callObjects;
    bytes[] returnObjects;
}

struct AdditionalData {
    bytes32 key;
    bytes value;
}

interface ICallBreaker {
    function executeAndVerify(
        UserObjective[] calldata userObjectives,
        uint256[] calldata _orderOfExecution,
        bytes[] calldata returnsBytes,
        AdditionalData[] calldata associatedData
    ) external payable;
}
