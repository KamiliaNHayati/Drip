// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Interface for VaultFactory — used by CompetitionManager to verify vaults
interface IVaultFactory {
    function vaultToToken(address vault) external view returns (address token);
    function isRegisteredVault(address vault) external view returns (bool);
    function allVaults(uint256 index) external view returns (address);
    function allVaultsLength() external view returns (uint256);
}
