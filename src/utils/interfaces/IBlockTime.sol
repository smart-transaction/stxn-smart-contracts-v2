// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

interface IBlockTime {
    struct Chronicle {
        uint256 epoch;
        address timeKeeper;
        bytes signature;
    }

    function moveTime(
        Chronicle[] calldata chronicles,
        uint256 meanCurrentEarthTime,
        address[] calldata receivers,
        uint256[] calldata amounts
    ) external;

    function getBlockTime() external view returns (uint256 blockStartEpoch, uint256 blockEndEpoch);

    function setMaxBlockWidth(uint256 _maxBlockWidth) external;

    function getMaxBlockWidth() external view returns (uint256);
}
