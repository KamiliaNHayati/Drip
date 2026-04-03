// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IDripVault} from "./interfaces/IDripVault.sol";
import {IDripToken} from "./interfaces/IDripToken.sol";

/// @title VaultFactory — Deploys DripVault + DripToken clone pairs
/// @notice Uses EIP-1167 minimal proxies. Creation fee paid in native INIT.
/// @dev Non-clone contract — uses standard Ownable. Clone init order: token first, vault second.
contract VaultFactory is Ownable, ReentrancyGuard {

    // ─── Events ────────────────────────────────────────────────────────
    event VaultCreated(address indexed vault, address indexed token, address indexed creator, string name);
    event TreasuryUpdated(address indexed newTreasury);

    // ─── Errors ────────────────────────────────────────────────────────
    error InsufficientCreationFee();
    error InvalidCreatorFee();
    error TransferFailed();
    error InvalidAddress();

    // ─── Storage ───────────────────────────────────────────────────────
    address public vaultImplementation;
    address public tokenImplementation;
    address public dripPool;
    address public connectOracle;
    address public treasury;
    uint256 public creationFee;
    uint256 public dripCutBps;
    address[] public allVaults;
    mapping(address => address[]) public vaultsByCreator;
    mapping(address => address) public vaultToToken;

    // ─── Constructor ───────────────────────────────────────────────────

    /// @notice Deploy the factory
    /// @param _vaultImpl Address of the DripVault implementation (template)
    /// @param _tokenImpl Address of the DripToken implementation (template)
    /// @param _dripPool Address of the DripPool
    /// @param _connectOracle Address of the Connect oracle precompile
    /// @param _treasury Protocol treasury address
    /// @param _creationFee Vault creation fee in native INIT (e.g. 3e18)
    /// @param _dripCutBps Protocol cut of creator fees in bps (e.g. 1000 = 10%)
    constructor(
        address _vaultImpl,
        address _tokenImpl,
        address _dripPool,
        address _connectOracle,
        address _treasury,
        uint256 _creationFee,
        uint256 _dripCutBps
    ) Ownable(msg.sender) {
        if (_vaultImpl == address(0) || _tokenImpl == address(0)) revert InvalidAddress();
        if (_dripPool == address(0) || _treasury == address(0)) revert InvalidAddress();

        vaultImplementation = _vaultImpl;
        tokenImplementation = _tokenImpl;
        dripPool = _dripPool;
        connectOracle = _connectOracle;
        treasury = _treasury;
        creationFee = _creationFee;
        dripCutBps = _dripCutBps;
    }

    // ─── Core ──────────────────────────────────────────────────────────

    /// @notice Create a new vault + token clone pair
    /// @param _name Vault name (also used for token: "drip{name}" / "d{name}")
    /// @param _description Vault description
    /// @param _creatorFeeBps Creator fee in bps (500–2000, i.e. 5%–20%)
    /// @return vault The deployed vault clone address
    /// @return token The deployed token clone address
    function createVault(
        string calldata _name,
        string calldata _description,
        uint256 _creatorFeeBps
    ) external payable nonReentrant returns (address vault, address token) {
        // Validate creation fee
        if (msg.value < creationFee) revert InsufficientCreationFee();

        // Validate creator fee bounds (5%–20%)
        if (_creatorFeeBps < 500 || _creatorFeeBps > 2000) revert InvalidCreatorFee();

        // Step 1: Deploy token clone (uninitialized)
        token = Clones.clone(tokenImplementation);

        // Step 2: Deploy vault clone (uninitialized)
        vault = Clones.clone(vaultImplementation);

        // Step 3: Initialize token with vault address
        IDripToken(token).initialize(
            vault,
            string.concat("drip", _name),
            string.concat("d", _name)
        );

        // Step 4: Initialize vault with token address
        IDripVault(vault).initialize(
            msg.sender,
            _name,
            _description,
            _creatorFeeBps,
            dripPool,
            token,
            connectOracle,
            treasury,
            dripCutBps
        );

        // Step 5: Transfer creation fee to treasury (refund excess)
        (bool success, ) = payable(treasury).call{value: creationFee}("");
        if (!success) revert TransferFailed();
        if (msg.value > creationFee) {
            (bool refundOk, ) = payable(msg.sender).call{value: msg.value - creationFee}("");
            if (!refundOk) revert TransferFailed();
        }

        // Step 6: Track vault
        allVaults.push(vault);
        vaultsByCreator[msg.sender].push(vault);
        vaultToToken[vault] = token;

        emit VaultCreated(vault, token, msg.sender, _name);
    }

    // ─── Admin ─────────────────────────────────────────────────────────

    /// @notice Update treasury address
    function setTreasuryAddress(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert InvalidAddress();
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    /// @notice Withdraw any stuck native INIT to treasury
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) return;
        (bool success, ) = payable(treasury).call{value: balance}("");
        if (!success) revert TransferFailed();
    }

    // ─── View ──────────────────────────────────────────────────────────

    /// @notice Get total number of vaults created
    function allVaultsLength() external view returns (uint256) {
        return allVaults.length;
    }

    /// @notice Get number of vaults for a creator
    function vaultsByCreatorLength(address _creator) external view returns (uint256) {
        return vaultsByCreator[_creator].length;
    }

    /// @notice Check if a vault was created by this factory
    function isRegisteredVault(address _vault) external view returns (bool) {
        return vaultToToken[_vault] != address(0);
    }
}