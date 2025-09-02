// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TimeToken is ERC20, Ownable {
    /// @dev Error thrown when array length mismatch
    error ArrayLengthMismatch();

    /// @notice Emitted when batch minitng
    event BatchMinted(address[] to, uint256[] amounts);

    constructor() ERC20("TimeToken", "TIME") Ownable(msg.sender) {}

    /// @notice mint token to the receivers
    /// @dev Requires caller to be the owner
    /// @param receivers The addresses going to receive TIME Token
    /// @param amounts The amount of TIME Token to be received
    function batchMint(address[] memory receivers, uint256[] memory amounts) public onlyOwner {
        if (receivers.length != amounts.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < receivers.length; ++i) {
            _mint(receivers[i], amounts[i]);
        }

        emit BatchMinted(receivers, amounts);
    }
}
