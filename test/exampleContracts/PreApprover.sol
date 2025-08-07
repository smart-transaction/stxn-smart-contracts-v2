// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

/// @title PreApprover
/// @notice A simple contract for testing pre-approval functionality
contract PreApprover {
    mapping(bytes32 => bool) public approvedRequests;

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
}
