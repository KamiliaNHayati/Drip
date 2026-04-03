// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Interface for DripVault interactions (used by VaultFactory + CompetitionManager)
interface IDripVault {
    function initialize(
        address _creator,
        string calldata _name,
        string calldata _description,
        uint256 _creatorFeeBps,
        address _dripPool,
        address _dripToken,
        address _connectOracle,
        address _treasury,
        uint256 _dripCutBps
    ) external;

    function totalAssets() external view returns (uint256);
    function dripToken() external view returns (address);
    function depositorCount() external view returns (uint256);
    function creator() external view returns (address);
    function name() external view returns (string memory);
    function poolShares() external view returns (uint256);
    function lastTotalAssets() external view returns (uint256);
    function creatorFeeBps() external view returns (uint256);
    function paused() external view returns (bool);
    function defensiveMode() external view returns (bool);

    function vaultInfo() external view returns (
        string memory _name,
        string memory _description,
        address _creator,
        uint256 _creatorFeeBps,
        uint256 _totalAssets,
        uint256 _totalShares,
        uint256 _depositorCount,
        bool _paused,
        bool _defensiveMode
    );
}
