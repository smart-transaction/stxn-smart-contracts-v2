// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.28;

contract Counter {
    uint256 public counter;

    event counterUpdated(uint256 newCounter);

    // External function to increment counter by 1
    function incrementCounter() external returns (uint256) {
        counter += 1;
        emit counterUpdated(counter);
        return counter;
    }
}
