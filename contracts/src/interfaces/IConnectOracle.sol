// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Connect oracle precompile on Initia Minitia (EVM)
/// @dev Address confirmed via: curl https://rest-evm-1.anvil.asia-southeast.initia.xyz/minievm/evm/v1/connect_oracle
/// @dev Returns: 0x031ECb63480983FD216D17BB6e1d393f3816b72F
/// @dev MUST compile with via_ir = true
interface IConnectOracle {
    struct Price {
        uint256 price;      // price * 10^decimal
        uint256 timestamp;  // unix timestamp
        uint64 height;
        uint64 nonce;
        uint64 decimal;
        uint64 id;
    }

    /// @notice Get the price for a single pair
    /// @param pair_id The pair identifier, e.g. "INIT/USD"
    function get_price(string memory pair_id) external view returns (Price memory);

    /// @notice Get prices for multiple pairs
    /// @param pair_ids Array of pair identifiers
    function get_prices(string[] memory pair_ids) external view returns (Price[] memory);
}
