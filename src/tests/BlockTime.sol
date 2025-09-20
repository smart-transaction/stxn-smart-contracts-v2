// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {TimeToken} from "src/tests/TimeToken.sol";
import {IBlockTime} from "src/utils/interfaces/IBlockTime.sol";

contract BlockTime is IBlockTime, AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SCHEDULER_ROLE = keccak256("SCHEDULER_ROLE");

    /// @dev minimum number of signed time values needed
    uint256 public minNumberOfChronicles;

    /// @notice value used to ensure the values being provided are not outliers
    uint256 private maxBlockWidth;

    /// @notice since the precision of time is low in this implementation we assume time to be anywhere
    ///         between current mean time and current mean time + time width
    ///         This can be in the future be modified to be an average of the difference between last X earthTimeValues
    uint256 public timeBlockWidth;

    /// @notice the current average of all time keepers provided time value
    uint256 public currentEarthTimeAvg;

    /// @notice The ERC20 timeToken that will be transferred to users on successfull time updation
    TimeToken public timeToken;

    error NotEnoughChronicles();

    event Tick(uint256 currentEarthTimeBlockStart, uint256 currentEarthTimeBlockEnd);
    event BlockTimeUpdated(
        uint256 newEarthTime, Chronicle[] chronicles, address[] timeTokenReceivers, uint256[] amounts
    );
    event MaxBlockWidthSet(uint256 maxBlockWidth);
    event MinNumberOfChroniclesSet(uint256 minNumberOfChronicles);

    constructor(address _admin) {
        timeToken = new TimeToken();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
    }

    /// @notice changes earth avg time
    /// @param chronicles List of chronicle data containing epoch, timeKeeper, and signature
    /// @param meanCurrentEarthTime The new average earth time to be set
    /// @param receivers List of addresses that will receive TimeToken rewards
    /// @param amounts List of amounts of TimeToken to be minted for each receiver
    function moveTime(
        Chronicle[] calldata chronicles,
        uint256 meanCurrentEarthTime,
        address[] calldata receivers,
        uint256[] calldata amounts
    ) external onlyRole(SCHEDULER_ROLE) nonReentrant {
        if (chronicles.length < minNumberOfChronicles) {
            revert NotEnoughChronicles();
        }
        currentEarthTimeAvg = meanCurrentEarthTime;
        timeToken.batchMint(receivers, amounts);
        emit BlockTimeUpdated(meanCurrentEarthTime, chronicles, receivers, amounts);
    }

    /// @notice returns current block time
    /// @return blockStartEpoch The start epoch of the current block
    /// @return blockEndEpoch The end epoch of the current block
    function getBlockTime() external view returns (uint256, uint256) {
        return (currentEarthTimeAvg, currentEarthTimeAvg + maxBlockWidth);
    }

    /// @notice Sets the maximum block width
    /// @param _maxBlockWidth The new maximum block width value
    function setMaxBlockWidth(uint256 _maxBlockWidth) external onlyRole(ADMIN_ROLE) {
        maxBlockWidth = _maxBlockWidth;
        emit MaxBlockWidthSet(_maxBlockWidth);
    }

    /// @notice Gets the maximum block width
    /// @return The current maximum block width value
    function getMaxBlockWidth() external view returns (uint256) {
        return maxBlockWidth;
    }

    /// @notice Sets minimum number of chronicles value
    /// @param _minNumberOfChronicles The new minimum number of chronicles value
    function setMinNumberOfChronicles(uint256 _minNumberOfChronicles) external onlyRole(ADMIN_ROLE) {
        minNumberOfChronicles = _minNumberOfChronicles;
        emit MinNumberOfChroniclesSet(_minNumberOfChronicles);
    }
}
