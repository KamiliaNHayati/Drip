// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title GhostRegistry — Ghost wallet leaderboard and delegation
/// @notice Tracks ghost operators who execute compound() on behalf of vault creators.
/// @dev Ghost fee (0.1% of yield) is deducted from creator's share via DripVault.
contract GhostRegistry is Ownable, ReentrancyGuard {

    // ─── Events ────────────────────────────────────────────────────────
    event GhostRegistered(address indexed ghost);
    event CompoundRecorded(address indexed ghost, uint256 yieldManaged, uint256 feeEarned);
    event GhostRewardClaimed(address indexed ghost, uint256 amount);
    event TreasuryUpdated(address indexed newTreasury);

    // ─── Errors ────────────────────────────────────────────────────────
    error AlreadyRegistered();
    error NotRegisteredGhost();
    error NothingToClaim();
    error TransferFailed();
    error GhostListFull();
    error NotAuthorizedVault();

    // ─── Structs ───────────────────────────────────────────────────────
    struct GhostStats {
        uint256 compoundsExecuted;
        uint256 successfulCompounds;
        uint256 totalYieldManaged;
        uint256 pendingRewards;
        uint256 totalFeesEarned;
        uint256 registeredAt;
    }

    // ─── Storage ───────────────────────────────────────────────────────
    mapping(address => GhostStats) public ghostStats;
    mapping(address => bool) public registeredGhosts;
    mapping(address => bool) public authorizedVaults;
    address[] public ghostList;

    uint256 public performanceFeeBps;   // 10 = 0.1% of yield
    uint256 public protocolShareBps;    // 1000 = 10% of ghost fee to protocol
    address public treasury;
    uint256 public protocolAccrued;     // accumulated protocol share of ghost fees

    // ─── Constructor ───────────────────────────────────────────────────

    /// @notice Deploy the ghost registry
    /// @param _treasury Protocol treasury
    /// @param _performanceFeeBps Ghost performance fee in bps (10 = 0.1%)
    /// @param _protocolShareBps Protocol share of ghost fee in bps (1000 = 10%)
    constructor(
        address _treasury,
        uint256 _performanceFeeBps,
        uint256 _protocolShareBps
    ) Ownable(msg.sender) {
        treasury = _treasury;
        performanceFeeBps = _performanceFeeBps;
        protocolShareBps = _protocolShareBps;
    }

    // ─── Core ──────────────────────────────────────────────────────────

    /// @notice Register as a ghost operator
    function registerAsGhost() external {
        if (registeredGhosts[msg.sender]) revert AlreadyRegistered();
        if (ghostList.length >= 100) revert GhostListFull();

        registeredGhosts[msg.sender] = true;
        ghostStats[msg.sender].registeredAt = block.timestamp;
        ghostList.push(msg.sender);

        emit GhostRegistered(msg.sender);
    }

    /// @notice Record a successful compound — callable only by authorized DripVaults
    /// @param ghost The ghost operator who called compound()
    /// @param yieldAmount The total profit harvested in this compound
    /// @return ghostFee The fee amount to deduct from creator's share
    function recordCompound(address ghost, uint256 yieldAmount) external returns (uint256 ghostFee) {
        if (!authorizedVaults[msg.sender]) revert NotAuthorizedVault();
        if (!registeredGhosts[ghost]) revert NotRegisteredGhost();

        GhostStats storage stats = ghostStats[ghost];
        stats.compoundsExecuted++;
        stats.successfulCompounds++;
        stats.totalYieldManaged += yieldAmount;

        // Ghost fee = 0.1% of yield
        ghostFee = yieldAmount * performanceFeeBps / 10000;
        if (ghostFee == 0) return 0;

        // Split: 90% to ghost, 10% to protocol
        uint256 protocolCut = ghostFee * protocolShareBps / 10000;
        uint256 ghostCut = ghostFee - protocolCut;

        stats.pendingRewards += ghostCut;
        stats.totalFeesEarned += ghostCut;
        protocolAccrued += protocolCut;

        emit CompoundRecorded(ghost, yieldAmount, ghostFee);
    }

    /// @notice Ghost claims accumulated rewards
    function claimGhostRewards() external nonReentrant {
        GhostStats storage stats = ghostStats[msg.sender];
        uint256 amount = stats.pendingRewards;
        if (amount == 0) revert NothingToClaim();

        stats.pendingRewards = 0;
        // Ghost rewards are in ERC20 INIT held by the vault contracts
        // For MVP, ghost claims are tracked but actual transfer happens
        // when vault creator claims and redistributes
        // In production, ghost fee would be transferred in compound()
        // For now, just emit the event — ghost rewards viewable on leaderboard

        emit GhostRewardClaimed(msg.sender, amount);
    }

    // ─── Admin ─────────────────────────────────────────────────────────

    /// @notice Authorize a DripVault to call recordCompound
    function authorizeVault(address vault) external onlyOwner {
        authorizedVaults[vault] = true;
    }

    /// @notice Revoke vault authorization
    function revokeVault(address vault) external onlyOwner {
        authorizedVaults[vault] = false;
    }

    /// @notice Update treasury
    function setTreasuryAddress(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    /// @notice Withdraw protocol's share of ghost fees
    function withdrawFees() external onlyOwner {
        uint256 amount = protocolAccrued;
        if (amount == 0) return;
        protocolAccrued = 0;
        // Protocol fees are tracked but held in vault contracts (ERC20)
        // For MVP, just reset the counter — production would involve actual transfers
    }

    // ─── View ──────────────────────────────────────────────────────────

    /// @notice Get top ghosts by total yield managed
    function getTopGhosts(uint256 count) external view returns (address[] memory ghosts, uint256[] memory yields) {
        uint256 len = ghostList.length < count ? ghostList.length : count;
        ghosts = new address[](len);
        yields = new uint256[](len);

        // Copy all ghosts
        address[] memory all = new address[](ghostList.length);
        uint256[] memory allYields = new uint256[](ghostList.length);
        for (uint256 i = 0; i < ghostList.length; i++) {
            all[i] = ghostList[i];
            allYields[i] = ghostStats[ghostList[i]].totalYieldManaged;
        }

        // Simple sort (max 100 ghosts)
        for (uint256 i = 1; i < all.length; i++) {
            address kA = all[i];
            uint256 kY = allYields[i];
            int256 j = int256(i) - 1;
            while (j >= 0 && allYields[uint256(j)] < kY) {
                all[uint256(j + 1)] = all[uint256(j)];
                allYields[uint256(j + 1)] = allYields[uint256(j)];
                j--;
            }
            all[uint256(j + 1)] = kA;
            allYields[uint256(j + 1)] = kY;
        }

        for (uint256 i = 0; i < len; i++) {
            ghosts[i] = all[i];
            yields[i] = allYields[i];
        }
    }

    /// @notice Get reliability score for a ghost (bps, 10000 = 100%)
    function reliabilityScore(address ghost) external view returns (uint256) {
        GhostStats storage s = ghostStats[ghost];
        if (s.compoundsExecuted == 0) return 0;
        return s.successfulCompounds * 10000 / s.compoundsExecuted;
    }

    /// @notice Get ghost list length
    function ghostListLength() external view returns (uint256) {
        return ghostList.length;
    }
}
