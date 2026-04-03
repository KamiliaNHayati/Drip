// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title DripToken — ERC20 receipt token for DripVault (EIP-1167 clone)
/// @notice Minted on deposit, burned on withdraw. Only the vault can mint/burn.
/// @dev OZ v5 ReentrancyGuard uses transient storage (EIP-1153) — no init needed, safe for clones.
///      Requires target chain to support EIP-1153 (Initia supports Dencun).
contract DripToken is ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuard {

    // ─── Errors ────────────────────────────────────────────────────────
    error OnlyVault();

    // ─── Storage ───────────────────────────────────────────────────────
    address public vault;

    // ─── Initialize (no constructor — clone pattern) ───────────────────

    /// @notice Initialize the token with vault address, name, and symbol
    /// @param _vault The DripVault that owns this token
    /// @param _name Token name (e.g. "dripMyVault")
    /// @param _symbol Token symbol (e.g. "dMyVault")
    function initialize(address _vault, string calldata _name, string calldata _symbol) external initializer {
        __ERC20_init(_name, _symbol);
        __Ownable_init(_vault);

        vault = _vault;
    }

    // ─── Vault-Only Functions ──────────────────────────────────────────

    /// @notice Mint receipt tokens to depositor
    function mint(address to, uint256 amount) external nonReentrant {
        if (msg.sender != vault) revert OnlyVault();
        _mint(to, amount);
    }

    /// @notice Burn receipt tokens on withdrawal
    function burn(address from, uint256 amount) external nonReentrant {
        if (msg.sender != vault) revert OnlyVault();
        _burn(from, amount);
    }
}
