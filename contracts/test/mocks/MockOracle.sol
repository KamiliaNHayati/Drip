// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IConnectOracle} from "../../src/interfaces/IConnectOracle.sol";

/// @dev Mock oracle for testing — supports setPrice(), setStale(), and setShouldRevert()
contract MockOracle is IConnectOracle {
    uint256 public mockPrice = 1e9;  // 1 USD with 9 decimals
    uint256 public mockTimestamp;
    bool public shouldRevert;

    constructor() {
        mockTimestamp = block.timestamp;
    }

    function setPrice(uint256 _price) external {
        mockPrice = _price;
        mockTimestamp = block.timestamp;
    }

    function setStale() external {
        mockTimestamp = block.timestamp - 120; // 2 min stale
    }

    function setShouldRevert(bool _revert) external {
        shouldRevert = _revert;
    }

    function get_price(string memory) external view returns (Price memory) {
        require(!shouldRevert, "Oracle error");
        return Price({
            price: mockPrice,
            timestamp: mockTimestamp,
            height: 0,
            nonce: 0,
            decimal: 9,
            id: 0
        });
    }

    function get_prices(string[] memory) external pure returns (Price[] memory) {
        revert("not implemented");
    }
}
