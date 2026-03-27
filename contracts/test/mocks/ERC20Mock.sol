// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title ERC20Mock — Mintable ERC20 for testing
contract ERC20Mock is ERC20 {
    constructor() ERC20("Mock INIT", "INIT") {}

    /// @notice Mint tokens to any address (test only)
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
