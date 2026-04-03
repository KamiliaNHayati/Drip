// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Interface for GhostRegistry — called by DripVault during compound
interface IGhostRegistry {
    function recordCompound(address ghost, uint256 yieldAmount) external returns (uint256 ghostFee);
    function registeredGhosts(address ghost) external view returns (bool);
}
