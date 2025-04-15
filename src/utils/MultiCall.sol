// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "src/interfaces/IMultiCall.sol";

/// @title Multicall Implementation
/// @notice Batch execute contract calls with full error capture
contract Multicall is IMulticall {
    /// @inheritdoc IMulticall
    function aggregate(
        Call[] calldata calls
    ) external payable override returns (Result[] memory results) {
        results = new Result[](calls.length);

        for (uint256 i = 0; i < calls.length; ) {
            address target = calls[i].target;
            bytes calldata callData = calls[i].callData;

            (bool success, bytes memory returnData) = target.call(callData);

            // Store results including failures
            results[i] = Result(success, returnData);

            // Used unchecked to optimize gas
            unchecked {
                ++i;
            }
        }
    }
}
