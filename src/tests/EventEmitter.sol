// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

contract EventEmitter {
    event TestEvent(uint256 value);

    function emitEvent(uint256 value) external {
        emit TestEvent(value);
    }

    function emitEventWithReturn(uint256 value) external returns (uint256) {
        emit TestEvent(value);
        return value;
    }

    function emitEventWithTrueReturn(uint256 value) external payable returns (bool) {
        emit TestEvent(value);
        return true;
    }

    function emitEventWithFalseReturn(uint256 value) external returns (bool) {
        emit TestEvent(value);
        return false;
    }
}
