// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract KITNToken is ERC20, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @dev Error thrown when array length mismatch
    error ArrayLengthMismatch();

    /// @notice Emitted when tokens are minted to multiple receivers
    event BatchMinted(address[] receivers, uint256[] amounts);

    constructor(address owner) ERC20("KITN Token", "KITN") {
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(MINTER_ROLE, owner);
        _grantRole(PAUSER_ROLE, owner);
    }

    /// @notice mint token to the receivers
    /// @dev Requires caller to have the MINTER_ROLE
    /// @param receivers The addresses going to receive KITN Token
    /// @param amounts The amount of KITN Token to be received
    function batchMint(address[] calldata receivers, uint256[] calldata amounts)
        external
        whenNotPaused
        onlyRole(MINTER_ROLE)
    {
        if (receivers.length != amounts.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < receivers.length; ++i) {
            _mint(receivers[i], amounts[i]);
        }

        emit BatchMinted(receivers, amounts);
    }

    /// @notice Pauses all contract functions protected by the `whenNotPaused` modifier
    /// @dev Requires caller to have the PAUSER_ROLE
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Unpauses all contract functions protected by the `whenNotPaused` modifier
    /// @dev Requires caller to have the PAUSER_ROLE
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
