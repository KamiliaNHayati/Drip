// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IDripVault} from "./interfaces/IDripVault.sol";
import {IDripToken} from "./interfaces/IDripToken.sol";
import {IVaultFactory} from "./interfaces/IVaultFactory.sol";

/// @title CompetitionManager — Yield competitions across Drip vaults
/// @notice Tracks PPS (price-per-share) growth. Prizes in native INIT.
/// @dev Non-clone contract — uses standard Ownable.
contract CompetitionManager is Ownable, ReentrancyGuard {

    // ─── Events ────────────────────────────────────────────────────────
    event CompetitionCreated(uint256 indexed id, address indexed vault, uint256 endTime, uint256 prizePool);
    event ParticipantEntered(uint256 indexed id, address indexed participant);
    event CompetitionSettled(uint256 indexed id, address indexed winner, uint256 winnerGrowthBps);
    event CompetitionCancelled(uint256 indexed id);
    event TreasuryUpdated(address indexed newTreasury);

    // ─── Errors ────────────────────────────────────────────────────────
    error InsufficientEntryFee();
    error CompetitionNotActive();
    error CompetitionNotEnded();
    error AlreadyEntered();
    error AlreadySettled();
    error VaultNotEligible();
    error NotRegisteredVault();
    error CompetitionFull();
    error InvalidDuration();
    error InsufficientSeed();
    error TransferFailed();

    // ─── Structs ───────────────────────────────────────────────────────

    struct Competition {
        address vault;
        uint256 startTime;
        uint256 endTime;
        uint256 prizePool;
        address[] participants;
        mapping(address => uint256) startPPS;
        mapping(address => bool) hasEntered;
        address winner;
        uint256 winnerGrowthBps;
        bool settled;
    }

    // ─── Storage ───────────────────────────────────────────────────────
    uint256 public competitionCount;
    mapping(uint256 => Competition) internal competitions;
    uint256 public entryFee;
    uint256 public protocolSeed;
    uint256 public dripCutBps;
    uint256 public maxParticipants;
    address public treasury;
    address public factory;
    uint256 public reservedSeeds;

    // ─── Constructor ───────────────────────────────────────────────────

    /// @notice Deploy the competition manager
    /// @param _factory Address of the VaultFactory
    /// @param _treasury Protocol treasury address
    /// @param _entryFee Entry fee in native INIT (e.g. 7e18)
    /// @param _protocolSeed Protocol seed per competition in native INIT (e.g. 23e18)
    /// @param _dripCutBps Protocol cut of prize pool in bps (e.g. 1000 = 10%)
    constructor(
        address _factory,
        address _treasury,
        uint256 _entryFee,
        uint256 _protocolSeed,
        uint256 _dripCutBps
    ) Ownable(msg.sender) {
        factory = _factory;
        treasury = _treasury;
        entryFee = _entryFee;
        protocolSeed = _protocolSeed;
        dripCutBps = _dripCutBps;
        maxParticipants = 100;
    }

    /// @notice Accept native INIT for seed pool funding
    receive() external payable {}

    // ─── Core ──────────────────────────────────────────────────────────

    /// @notice Create a new yield competition for a vault
    /// @param vault The vault to compete on
    /// @param duration Competition duration in seconds (1 hour – 30 days)
    function createCompetition(address vault, uint256 duration) external nonReentrant {
        // Validate vault is from registered factory
        if (!IVaultFactory(factory).isRegisteredVault(vault)) revert NotRegisteredVault();

        // Validate depositorCount >= 2
        if (IDripVault(vault).depositorCount() < 2) revert VaultNotEligible();

        // Validate duration (1 hour to 30 days)
        if (duration < 3600 || duration > 2592000) revert InvalidDuration();

        // Require sufficient unreserved balance for seed
        uint256 available = address(this).balance - reservedSeeds;
        if (available < protocolSeed) revert InsufficientSeed();
        reservedSeeds += protocolSeed;

        uint256 id = competitionCount++;
        Competition storage c = competitions[id];
        c.vault = vault;
        c.startTime = block.timestamp;
        c.endTime = block.timestamp + duration;
        c.prizePool = protocolSeed;

        emit CompetitionCreated(id, vault, c.endTime, c.prizePool);
    }

    /// @notice Enter an active competition
    /// @param id Competition ID
    function enterCompetition(uint256 id) external payable nonReentrant {
        Competition storage c = competitions[id];

        if (c.vault == address(0)) revert CompetitionNotActive();
        if (block.timestamp >= c.endTime) revert CompetitionNotActive();
        if (c.settled) revert AlreadySettled();
        if (c.hasEntered[msg.sender]) revert AlreadyEntered();
        if (c.participants.length >= maxParticipants) revert CompetitionFull();
        if (msg.value < entryFee) revert InsufficientEntryFee();

        // Snapshot PPS at entry time
        uint256 currentTotalAssets = IDripVault(c.vault).totalAssets();
        address token = IDripVault(c.vault).dripToken();
        uint256 currentTotalSupply = IDripToken(token).totalSupply();

        // PPS = totalAssets * 1e18 / totalSupply
        uint256 pps = currentTotalSupply > 0
            ? currentTotalAssets * 1e18 / currentTotalSupply
            : 0;

        c.startPPS[msg.sender] = pps;
        c.hasEntered[msg.sender] = true;
        c.participants.push(msg.sender);
        c.prizePool += entryFee;

        if (msg.value > entryFee) {
            (bool refundOk, ) = payable(msg.sender).call{value: msg.value - entryFee}("");
            if (!refundOk) revert TransferFailed();
        }

        emit ParticipantEntered(id, msg.sender);
    }

    /// @notice Settle a competition after endTime
    /// @param id Competition ID
    function settleCompetition(uint256 id) external nonReentrant {
        Competition storage c = competitions[id];

        if (c.vault == address(0)) revert CompetitionNotActive();
        if (block.timestamp < c.endTime) revert CompetitionNotEnded();
        if (c.settled) revert AlreadySettled();

        c.settled = true;
        reservedSeeds -= protocolSeed;

        // Get current vault state
        uint256 currentTotalAssets = IDripVault(c.vault).totalAssets();
        address token = IDripVault(c.vault).dripToken();
        uint256 currentTotalSupply = IDripToken(token).totalSupply();

        // Find winner by highest PPS growth
        address bestParticipant = address(0);
        uint256 maxGrowth = 0;

        for (uint256 i = 0; i < c.participants.length; i++) {
            address p = c.participants[i];
            uint256 growth = _calculateGrowth(
                c.startPPS[p],
                currentTotalAssets,
                currentTotalSupply
            );
            if (growth > maxGrowth || (growth == maxGrowth && bestParticipant == address(0))) {
                maxGrowth = growth;
                bestParticipant = p;
            }
        }

        // If all 0% growth — refund path
        if (maxGrowth == 0) {
            _handleZeroGrowth(c);
            emit CompetitionCancelled(id);
            return;
        }

        // Winner found — distribute prize
        c.winner = bestParticipant;
        c.winnerGrowthBps = maxGrowth;

        uint256 dripFee = c.prizePool * dripCutBps / 10000;
        uint256 winnerPrize = c.prizePool - dripFee;

        // Pay treasury
        (bool s1, ) = payable(treasury).call{value: dripFee}("");
        if (!s1) revert TransferFailed();

        // Pay winner
        (bool s2, ) = payable(bestParticipant).call{value: winnerPrize}("");
        if (!s2) revert TransferFailed();

        emit CompetitionSettled(id, bestParticipant, maxGrowth);
    }

    // ─── Internal ──────────────────────────────────────────────────────

    /// @dev Calculate PPS growth in bps (safe uint256, no int256)
    function _calculateGrowth(
        uint256 startPPS,
        uint256 currentTotalAssets,
        uint256 currentTotalSupply
    ) internal pure returns (uint256 growthBps) {
        if (startPPS == 0 || currentTotalSupply == 0) return 0;
        uint256 currentPPS = currentTotalAssets * 1e18 / currentTotalSupply;
        if (currentPPS <= startPPS) return 0;
        growthBps = (currentPPS - startPPS) * 10000 / startPPS;
    }

    /// @dev Handle 0% growth: refund 95% of entry fees, protocol keeps 5% + seed
    function _handleZeroGrowth(Competition storage c) internal {
        uint256 totalEntryFees = c.prizePool > protocolSeed
            ? c.prizePool - protocolSeed
            : 0;

        uint256 protocolKeep = totalEntryFees * 500 / 10000; // 5%
        uint256 refundPool = totalEntryFees - protocolKeep;

        // Send protocol's 5% to treasury
        if (protocolKeep > 0) {
            payable(treasury).call{value: protocolKeep}("");
            // Intentionally ignore failure — bad treasury shouldn't block refunds
        }

        // Refund participants proportionally
        if (refundPool > 0 && c.participants.length > 0) {
            uint256 perPerson = refundPool / c.participants.length;
            for (uint256 i = 0; i < c.participants.length; i++) {
                payable(c.participants[i]).call{value: perPerson}("");
                // Intentionally ignore failure — bad actor cannot block others
            }
        }
    }

    // ─── Admin ─────────────────────────────────────────────────────────

    /// @notice Update treasury address
    function setTreasuryAddress(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    /// @notice Withdraw unreserved funds to treasury (does not touch active competition seeds)
    function withdrawFees() external onlyOwner {
        uint256 withdrawable = address(this).balance > reservedSeeds
            ? address(this).balance - reservedSeeds
            : 0;
        if (withdrawable == 0) return;
        (bool success, ) = payable(treasury).call{value: withdrawable}("");
        if (!success) revert TransferFailed();
    }

    /// @notice Admin deposits INIT for seeding competitions
    function fundSeedPool() external payable onlyOwner {}

    // ─── View ──────────────────────────────────────────────────────────

    /// @notice Get participants of a competition
    function getParticipants(uint256 id) external view returns (address[] memory) {
        return competitions[id].participants;
    }

    /// @notice Get competition info
    function getCompetition(uint256 id) external view returns (
        address vault,
        uint256 startTime,
        uint256 endTime,
        uint256 prizePool,
        uint256 participantCount,
        address winner,
        uint256 winnerGrowthBps,
        bool settled
    ) {
        Competition storage c = competitions[id];
        return (
            c.vault,
            c.startTime,
            c.endTime,
            c.prizePool,
            c.participants.length,
            c.winner,
            c.winnerGrowthBps,
            c.settled
        );
    }

    /// @notice Get leaderboard: ranked participants with growth bps
    function getLeaderboard(uint256 id) external view returns (
        address[] memory ranked,
        uint256[] memory growthBps
    ) {
        Competition storage c = competitions[id];
        uint256 len = c.participants.length;

        ranked = new address[](len);
        growthBps = new uint256[](len);

        uint256 currentTotalAssets = IDripVault(c.vault).totalAssets();
        address token = IDripVault(c.vault).dripToken();
        uint256 currentTotalSupply = IDripToken(token).totalSupply();

        // Calculate growth for each
        for (uint256 i = 0; i < len; i++) {
            ranked[i] = c.participants[i];
            growthBps[i] = _calculateGrowth(
                c.startPPS[c.participants[i]],
                currentTotalAssets,
                currentTotalSupply
            );
        }

        // Simple insertion sort (max 100 participants)
        for (uint256 i = 1; i < len; i++) {
            address keyAddr = ranked[i];
            uint256 keyGrowth = growthBps[i];
            int256 j = int256(i) - 1;
            while (j >= 0 && growthBps[uint256(j)] < keyGrowth) {
                ranked[uint256(j + 1)] = ranked[uint256(j)];
                growthBps[uint256(j + 1)] = growthBps[uint256(j)];
                j--;
            }
            ranked[uint256(j + 1)] = keyAddr;
            growthBps[uint256(j + 1)] = keyGrowth;
        }
    }

    /// @notice Check if competition can be settled
    function canSettle(uint256 id) external view returns (bool) {
        Competition storage c = competitions[id];
        return c.vault != address(0) && block.timestamp >= c.endTime && !c.settled;
    }

    /// @notice Get startPPS for a participant
    function getStartPPS(uint256 id, address participant) external view returns (uint256) {
        return competitions[id].startPPS[participant];
    }
}
