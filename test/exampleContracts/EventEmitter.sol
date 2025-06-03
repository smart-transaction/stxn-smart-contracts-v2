// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.28;

contract EventEmitter {
    bool public isEventEmitted;

    event TestEvent(uint256 value);

    function emitEvent(uint256 value) external {
        emit TestEvent(value);
    }

    function emitEventWithReturn(uint256 value) external returns (uint256) {
        emit TestEvent(value);
        return value;
    }

    function emitEventWithBoolReturn(uint256 value) external returns (bool) {
        isEventEmitted = true;
        emit TestEvent(value);
        return isEventEmitted;
    }

    function emitEventWithFalseReturn(uint256 value) external returns (bool) {
        emit TestEvent(value);
        return false;
    }
}
