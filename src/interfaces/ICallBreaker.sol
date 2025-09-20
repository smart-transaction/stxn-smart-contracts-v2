// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

import {UserObjective, CallObject, AdditionalData} from "src/interfaces/ISmartExecute.sol";

struct MevTimeData {
    bytes validatorSignature;
    AdditionalData[] mevTimeDataValues;
}

interface ICallBreaker {
    function executeAndVerify(
        UserObjective[] calldata _userObjectives,
        bytes[] calldata _returnsBytes,
        uint256[] calldata _orderOfExecution,
        MevTimeData calldata _mevTimeData
    ) external payable;

    function expectFutureCall(CallObject calldata _callObject) external returns (bool isExecutedInFuture);

    function mevTimeDataStore(bytes32 _key) external view returns (bytes memory);
}
