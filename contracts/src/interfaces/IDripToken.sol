// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Minimal interface for DripToken interactions
interface IDripToken {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}
