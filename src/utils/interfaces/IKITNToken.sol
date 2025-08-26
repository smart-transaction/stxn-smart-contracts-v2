// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

interface IKITNToken {
    function batchMint(address[] memory to, uint256[] memory amounts) external;
}
