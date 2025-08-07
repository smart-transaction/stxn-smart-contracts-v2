// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IMultiCall3 Interface
/// @notice Interface for MultiCall3 contract supporting multiple aggregation methods
interface IMultiCall3 {
    /// @notice Basic call structure
    /// @param target Address of the contract to call
    /// @param callData Calldata to send to the target
    struct Call {
        address target;
        bytes callData;
    }

    /// @notice Enhanced call structure with failure allowance
    /// @param target Address of the contract to call
    /// @param allowFailure Whether to allow call failure
    /// @param callData Calldata to send to the target
    struct Call3 {
        address target;
        bool allowFailure;
        bytes callData;
    }

    /// @notice Value-bearing call structure with failure allowance
    /// @param target Address of the contract to call
    /// @param allowFailure Whether to allow call failure
    /// @param value ETH value to send with call
    /// @param callData Calldata to send to the target
    struct Call3Value {
        address target;
        bool allowFailure;
        uint256 value;
        bytes callData;
    }

    /// @notice Result structure for call executions
    /// @param success Whether the call succeeded
    /// @param returnData Data returned from the call
    struct Result {
        bool success;
        bytes returnData;
    }

    /// @notice Basic aggregation method (Multicall-compatible)
    /// @param calls Array of Call structs
    /// @return blockNumber Current block number
    /// @return returnData Array of return bytes
    function aggregate(Call[] calldata calls)
        external
        payable
        returns (uint256 blockNumber, bytes[] memory returnData);

    /// @notice Aggregation with failure control
    /// @param requireSuccess Whether to require all calls to succeed
    /// @param calls Array of Call structs
    /// @return returnData Array of Result structs
    function tryAggregate(bool requireSuccess, Call[] calldata calls)
        external
        payable
        returns (Result[] memory returnData);

    /// @notice Aggregation with block context and failure control
    /// @param requireSuccess Whether to require all calls to succeed
    /// @param calls Array of Call structs
    /// @return blockNumber Current block number
    /// @return blockHash Current block hash
    /// @return returnData Array of Result structs
    function tryBlockAndAggregate(bool requireSuccess, Call[] calldata calls)
        external
        payable
        returns (uint256 blockNumber, bytes32 blockHash, Result[] memory returnData);

    /// @notice Block-aware aggregation (Multicall2-compatible)
    /// @param calls Array of Call structs
    /// @return blockNumber Current block number
    /// @return blockHash Current block hash
    /// @return returnData Array of Result structs
    function blockAndAggregate(Call[] calldata calls)
        external
        payable
        returns (uint256 blockNumber, bytes32 blockHash, Result[] memory returnData);

    /// @notice Enhanced aggregation with per-call failure control
    /// @param calls Array of Call3 structs
    /// @return returnData Array of Result structs
    function aggregate3(Call3[] calldata calls) external payable returns (Result[] memory returnData);

    /// @notice Value-bearing aggregation with per-call failure control
    /// @param calls Array of Call3Value structs
    /// @return returnData Array of Result structs
    function aggregate3Value(Call3Value[] calldata calls) external payable returns (Result[] memory returnData);

    /// @notice Get block hash for specific block number
    /// @param blockNumber Block number to query
    /// @return blockHash Hash of the specified block
    function getBlockHash(uint256 blockNumber) external view returns (bytes32 blockHash);

    /// @notice Get current block number
    /// @return blockNumber Current block number
    function getBlockNumber() external view returns (uint256 blockNumber);

    /// @notice Get current block coinbase
    /// @return coinbase Address of current block's coinbase
    function getCurrentBlockCoinbase() external view returns (address coinbase);

    /// @notice Get current block difficulty
    /// @return difficulty Current block difficulty
    function getCurrentBlockDifficulty() external view returns (uint256 difficulty);

    /// @notice Get current block gas limit
    /// @return gaslimit Current block gas limit
    function getCurrentBlockGasLimit() external view returns (uint256 gaslimit);

    /// @notice Get current block timestamp
    /// @return timestamp Current block timestamp
    function getCurrentBlockTimestamp() external view returns (uint256 timestamp);

    /// @notice Get ETH balance of an address
    /// @param addr Address to query
    /// @return balance ETH balance of the address
    function getEthBalance(address addr) external view returns (uint256 balance);

    /// @notice Get previous block hash
    /// @return blockHash Hash of the previous block
    function getLastBlockHash() external view returns (bytes32 blockHash);

    /// @notice Get current block base fee
    /// @return basefee Current block base fee
    function getBasefee() external view returns (uint256 basefee);

    /// @notice Get current chain ID
    /// @return chainid Current network chain ID
    function getChainId() external view returns (uint256 chainid);
}
