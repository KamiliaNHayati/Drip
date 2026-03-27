// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Minimal interface for DripPool interactions
interface IDripPool {
    function supply(uint256 amount) external returns (uint256 shares);
    function withdraw(uint256 shares) external returns (uint256 amount);
    function previewWithdraw(uint256 shares) external view returns (uint256 amount);
    function previewSupply(uint256 amount) external view returns (uint256 shares);
    function lenderShares(address lender) external view returns (uint256);
    function asset() external view returns (IERC20);
    function getActualDebt(address borrower) external view returns (uint256);
}
