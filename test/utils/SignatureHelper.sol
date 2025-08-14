// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import {UserObjective} from "src/interfaces/ICallBreaker.sol";
import {CallBreaker} from "src/CallBreaker.sol";

contract SignatureHelper is Test {
    CallBreaker public callBreaker;

    constructor(CallBreaker _callBreaker) {
        callBreaker = _callBreaker;
    }

    function generateSignature(UserObjective memory userObj, uint256 signerKey)
        external
        view
        returns (bytes memory signature)
    {
        bytes32 messageHash = callBreaker.getMessageHash(userObj);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, messageHash);
        signature = abi.encodePacked(r, s, v);
    }
}
