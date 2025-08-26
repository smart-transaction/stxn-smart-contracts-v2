// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

import {IApprover, UserObjective} from "src/interfaces/IApprover.sol";

/// @title PreApprover
/// @notice A simple contract for testing pre-approval functionality
contract PreApprover is IApprover {
    mapping(bytes32 => bool) public approvedRequests;
    bool public shouldApprove = true;

    /// @notice Approves a request by its ID
    /// @param requestId The request ID to approve
    /// @return True if the request was approved
    function preApprove(bytes32 requestId) external payable returns (bool) {
        approvedRequests[requestId] = true;
        return true;
    }

    /// @notice Rejects a request by its ID
    /// @param requestId The request ID to reject
    /// @return False to indicate rejection
    function preReject(bytes32 requestId) external payable returns (bool) {
        approvedRequests[requestId] = false;
        return false;
    }

    /// @notice Checks if a request is approved
    /// @param requestId The request ID to check
    /// @return True if the request is approved
    function isApproved(bytes32 requestId) external view returns (bool) {
        return approvedRequests[requestId];
    }

    /// @notice Function that always returns true for testing
    /// @return Always returns true
    function alwaysApprove() external pure returns (bool) {
        return true;
    }

    /// @notice Function that always returns false for testing
    /// @return Always returns false
    function alwaysReject() external pure returns (bool) {
        return false;
    }

    /// @notice Sets whether the contract should approve or reject requests
    /// @param _shouldApprove Whether to approve requests
    function setShouldApprove(bool _shouldApprove) external {
        shouldApprove = _shouldApprove;
    }

    /// @notice Implements IApprover.preapprove
    /// @return True if approved, false if rejected
    function preapprove(UserObjective calldata /*_userObjective*/ ) external payable returns (bool) {
        return shouldApprove;
    }

    /// @notice Implements IApprover.postapprove
    /// @return True if approved, false if rejected
    function postapprove(UserObjective[] calldata, /*_userObjectives*/ bytes[] calldata /*_returnData*/ )
        external
        view
        returns (bool)
    {
        return shouldApprove;
    }
}
