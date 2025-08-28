// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

import {IBlockTime} from "src/utils/interfaces/IBlockTime.sol";
import {CallBreaker} from "src/CallBreaker.sol";
import {CallObject, UserObjective, AdditionalData} from "src/interfaces/ICallBreaker.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @notice This is an POC example of a block scheduler
 */
contract BlockTimeScheduler is Ownable {
    address public callBreaker;
    address public reschedulerAddress;
    IBlockTime public blockTime;

    /// @dev Error thrown when address is zero
    /// @dev 0xd92e233d
    error ZeroAddress();

    /// @dev Error thrown when receive invalid data from callBreaker
    /// @dev 0xf0c7cf53
    error InvalidDataFromCallBreaker();

    /// @dev Error thrown when caller is not the callBreaker
    /// @dev 0x24ed5a32
    /// @param caller The address of the caller
    /// @param callBreaker The address of the callBreaker
    error UnauthorisedCaller(address caller, address callBreaker);

    /// @notice Emitted when callBreaker is updated
    /// @param callBreaker The address of the new callBreaker
    event CallBreakerUpdated(address indexed callBreaker);

    /// @notice Emitted when reschedulerAddress is updated
    /// @param reschedulerAddress The address of the new rescheduler
    event ReschedulerAddressUpdated(address indexed reschedulerAddress);

    modifier onlyCallBreaker() {
        if (msg.sender != callBreaker) {
            revert UnauthorisedCaller(msg.sender, callBreaker);
        }
        _;
    }

    constructor(address _callBreaker, address _blockTime, address _owner, address _reschedulerAddress)
        Ownable(_owner)
    {
        if (_callBreaker == address(0) || _blockTime == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }

        callBreaker = _callBreaker;
        blockTime = IBlockTime(_blockTime);
        reschedulerAddress = _reschedulerAddress;
    }

    /// @dev Requires caller to be the callBreaker
    function updateTime() external onlyCallBreaker {
        bytes memory chroniclesData =
            CallBreaker(payable(callBreaker)).mevTimeDataStore(keccak256(abi.encodePacked("Chronicles")));
        bytes memory meanTimeData =
            CallBreaker(payable(callBreaker)).mevTimeDataStore(keccak256(abi.encodePacked("CurrentMeanTime")));
        bytes memory recievers =
            CallBreaker(payable(callBreaker)).mevTimeDataStore(keccak256(abi.encodePacked("Recievers")));
        bytes memory amounts =
            CallBreaker(payable(callBreaker)).mevTimeDataStore(keccak256(abi.encodePacked("Amounts")));

        if (chroniclesData.length == 0 || meanTimeData.length == 0 || recievers.length == 0 || amounts.length == 0) {
            revert InvalidDataFromCallBreaker();
        }

        blockTime.moveTime(
            abi.decode(chroniclesData, (IBlockTime.Chronicle[])),
            abi.decode(meanTimeData, (uint256)),
            abi.decode(recievers, (address[])),
            abi.decode(amounts, (uint256[]))
        );

        // expected future call
        CallObject[] memory futureUserCallObj = new CallObject[](1);
        futureUserCallObj[0] = CallObject({
            salt: 1,
            amount: 0,
            gas: 1000000,
            addr: address(this),
            callvalue: abi.encodeWithSignature("updateTime()"),
            returnvalue: "",
            skippable: false,
            verifiable: true,
            exposeReturn: false
        });

        //expected userObjective
        UserObjective memory futureUserObj = UserObjective({
            appId: hex"01",
            nonce: 1,
            tip: 0,
            chainId: block.chainid,
            maxFeePerGas: 0,
            maxPriorityFeePerGas: 0,
            sender: reschedulerAddress,
            callObjects: futureUserCallObj
        });

        CallObject memory callObj = CallObject({
            salt: 0,
            amount: 0,
            gas: 1000000,
            addr: address(callBreaker),
            callvalue: abi.encodeWithSignature(
                "pushUserObjective((bytes,uint256,uint256,uint256,uint256,uint256,address,(uint256,uint256,uint256,address,bytes,bytes,bool,bool,bool)[]),(bytes32,bytes)[])",
                futureUserObj,
                new AdditionalData[](0)
            ),
            returnvalue: "",
            skippable: false,
            verifiable: false,
            exposeReturn: false
        });

        CallBreaker(payable(callBreaker)).expectFutureCall(callObj);
    }

    function setCallBreaker(address _callBreaker) external onlyOwner {
        if (_callBreaker == address(0)) {
            revert ZeroAddress();
        }
        callBreaker = _callBreaker;
        emit CallBreakerUpdated(_callBreaker);
    }

    function setReschedulerAddress(address _reschedulerAddress) external onlyOwner {
        if (_reschedulerAddress == address(0)) {
            revert ZeroAddress();
        }
        reschedulerAddress = _reschedulerAddress;
        emit ReschedulerAddressUpdated(_reschedulerAddress);
    }
}
