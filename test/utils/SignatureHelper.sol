// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import {UserObjective, AdditionalData, CallObject} from "src/interfaces/ICallBreaker.sol";
import {CallBreaker} from "src/CallBreaker.sol";

contract SignatureHelper is Test {
    CallBreaker public callBreaker;

    constructor(CallBreaker _callBreaker) {
        callBreaker = _callBreaker;
    }

    function generateSignature(uint256 nonce, address sender, uint256 signerKey, CallObject[] memory callObjects)
        external
        view
        returns (bytes memory signature)
    {
        bytes32 messageHash = callBreaker.getMessageHash(abi.encode(nonce, sender, abi.encode(callObjects)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, messageHash);
        signature = abi.encodePacked(r, s, v);
    }

    function generateValidatorSignature(AdditionalData[] memory mevTimeData, uint256 signerKey)
        external
        view
        returns (bytes memory signature)
    {
        bytes32 messageHash = callBreaker.getMessageHash(abi.encode(mevTimeData));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, messageHash);
        signature = abi.encodePacked(r, s, v);
    }

    function generateInvalidSignaturesUsingLength() external pure returns (bytes memory) {
        bytes memory signature;
        signature = abi.encodePacked(bytes32(0), bytes32(0)); // Incorrect length (missing v)
        return signature;
    }
}
