// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

import {IKITNToken} from "src/utils/interfaces/IKITNToken.sol";
import {CallBreaker} from "src/CallBreaker.sol";
import {DisbursalData, IKITNDisbursement} from "src/utils/interfaces/IKITNDisbursement.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract KITNDisbursement is IKITNDisbursement, Ownable {
    IKITNToken public immutable KITNToken;
    address public callBreaker;

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

    /// @notice Emitted when Kitn Tokens are transferred to receivers
    /// @param receivers The addresses going to receive KITN Token
    /// @param amounts The amount of KITN Token to be received
    event TokensDisbursed(address[] receivers, uint256[] amounts);

    /// @notice Emitted when callBreaker is updated
    /// @param callBreaker The address of the new callBreaker
    event CallBreakerUpdated(address indexed callBreaker);

    modifier onlyCallBreaker() {
        if (msg.sender != callBreaker) {
            revert UnauthorisedCaller(msg.sender, callBreaker);
        }
        _;
    }

    constructor(address _callBreaker, address _kitnToken, address _owner) Ownable(_owner) {
        if (_callBreaker == address(0) || _kitnToken == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }

        KITNToken = IKITNToken(_kitnToken);
        callBreaker = _callBreaker;
    }

    /// @notice Transfer token to receivers
    /// @dev Requires caller to be the callBreaker
    function disburseTokens() external onlyCallBreaker {
        // Retrieve data from CallBreaker's mevTimeStore
        bytes32 key = keccak256(abi.encodePacked("KITNDisbursementData"));
        bytes memory data = CallBreaker(payable(callBreaker)).mevTimeDataStore(key);
        if (data.length == 0) {
            revert InvalidDataFromCallBreaker();
        }

        // Execute KitnToken transfer
        DisbursalData memory disbursalData = abi.decode(data, (DisbursalData));
        KITNToken.batchMint(disbursalData.receivers, disbursalData.amounts);
        emit TokensDisbursed(disbursalData.receivers, disbursalData.amounts);
    }

    function setCallBreaker(address _callBreaker) external onlyOwner {
        if (_callBreaker == address(0)) {
            revert ZeroAddress();
        }
        callBreaker = _callBreaker;
        emit CallBreakerUpdated(_callBreaker);
    }
}
