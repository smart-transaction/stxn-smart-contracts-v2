// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.28;

/// @dev Struct for holding call object details
struct CallObject {
    uint256 salt;
    uint256 amount;
    uint256 chainId;
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
    address sender;
    CallObject[] callObjects;
    bytes[] returnValues;
}

struct MEVTimeData {
    bytes32 key;
    bytes value;
}

interface ICallBreaker {
    function executeAndVerify(
        UserObjective[] calldata _userObjectives,
        bytes[] calldata _signatures,
        bytes[] calldata _returnsBytes,
        uint256[] calldata _orderOfExecution,
        MEVTimeData[] calldata _mevTimeData
    ) external payable;
}
