// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IKITNToken} from "src/utils/interfaces/IKITNToken.sol";
import {CallBreaker} from "src/CallBreaker.sol";
import {DisbursalData} from "src/utils/interfaces/IKITNDisburement.sol";

contract KITNDisbursement is AccessControl, EIP712 {
    bytes32 public constant DISBURSER_ROLE = keccak256("DISBURSER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    bytes32 private constant DISBURSAL_DATA_TYPEHASH = keccak256("DisbursalData(address[] receivers,uint256[] amounts)");

    IKITNToken public immutable KITNToken;
    address public immutable callBreaker;

    /// @dev Error thrown when signature length is not equal to 65
    /// @dev 0x4be6321b
    error InvalidSignatureLength();
    /// @dev Error thrown when a signature verification fails due to mismatch between recovered signer and expected signer
    /// @dev 0x24ed5a32
    /// @param recoveredAddress The address recovered from the signature
    /// @param signer The expected signer address
    error UnauthorisedSigner(address recoveredAddress, address signer);
    /// @dev Error thrown when address is zero
    /// @dev 0xd92e233d
    error ZeroAddress();
    /// @dev Error thrown when receive invalid data from callBreaker
    /// @dev 0xf0c7cf53
    error InvalidDataFromCallBreaker();

    /// @notice Emited when Kitn Tokens are transfered to receivers
    /// @param receivers The addresses going to receive KITN Token
    /// @param amounts The amount of KITN Token to be received
    event TokensDisbursed(address[] indexed receivers, uint256[] amounts);

    constructor(address _callBreaker, address _kitnToken, address _owner) EIP712("KITNDisbursement", "1") {
        if (_callBreaker == address(0) || _kitnToken == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(ADMIN_ROLE, _owner);
        _grantRole(DISBURSER_ROLE, _callBreaker);

        KITNToken = IKITNToken(_kitnToken);
        callBreaker = _callBreaker;
    }

    /// @notice verifies the validatorNodeSignature and transfer token to receivers
    /// @dev Requires caller to have DISBURSER_ROLE
    function disburseTokens() external onlyRole(DISBURSER_ROLE) {
        // Retrieve data from CallBreaker's mevTimeStore
        bytes32 key = keccak256(abi.encodePacked("KITNDisbursalData"));
        bytes memory data = CallBreaker(payable(callBreaker)).mevTimeDataStore(key);
        if (data.length == 0) {
            revert InvalidDataFromCallBreaker();
        }

        // Execute KitnToken transfer
        DisbursalData memory disbursalData = abi.decode(data, (DisbursalData));
        KITNToken.batchMint(disbursalData.receivers, disbursalData.amounts);
        emit TokensDisbursed(disbursalData.receivers, disbursalData.amounts);
    }
}
