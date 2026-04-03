// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IDripVault} from "./interfaces/IDripVault.sol";
import {IDripToken} from "./interfaces/IDripToken.sol";
import {IVaultFactory} from "./interfaces/IVaultFactory.sol";

/// @title BattleManager — 1v1 vault-to-vault yield battles
/// @notice Creators challenge rival vaults. Winner takes 80% of combined stakes.
/// @dev Non-clone contract. All payouts in native INIT via .call.
contract BattleManager is Ownable, ReentrancyGuard {

    // ─── Events ────────────────────────────────────────────────────────
    event BattleDeclared(uint256 indexed id, address indexed challengerVault, address indexed defenderVault, uint256 endTime);
    event BattleAccepted(uint256 indexed id, address indexed defenderVault, uint256 startTime);
    event BattleCancelled(uint256 indexed id, uint256 refundAmount);
    event BattleSettled(uint256 indexed id, address indexed winnerVault, uint256 winnerPayout, uint256 protocolFee);

    // ─── Errors ────────────────────────────────────────────────────────
    error InvalidVault();
    error BattleInProgress();
    error InsufficientStake();
    error BattleNotEnded();
    error AlreadySettled();
    error InsufficientChallengeFee();
    error BattleAlreadyAccepted();
    error AcceptanceWindowOpen();
    error NotChallenger();
    error NotDefenderCreator();
    error BattleNotFound();
    error TransferFailed();

    // ─── Structs ───────────────────────────────────────────────────────
    struct Battle {
        address challengerVault;
        address defenderVault;
        uint256 challengerStake;
        uint256 defenderStake;
        uint256 startPPS_challenger;
        uint256 startPPS_defender;
        uint256 declaredAt;
        uint256 startTime;
        uint256 endTime;
        address winner;
        bool settled;
    }

    // ─── Storage ───────────────────────────────────────────────────────
    uint256 public battleCount;
    mapping(uint256 => Battle) public battles;
    mapping(address => uint256) public vaultActiveBattle;
    uint256 public challengeFee;
    uint256 public protocolCutBps;
    uint256 public minWager;
    uint256 public acceptanceWindow;
    address public factory;
    address public treasury;
    uint256 public totalActiveStakes;

    // ─── Constructor ───────────────────────────────────────────────────

    /// @notice Deploy the battle manager
    constructor(
        address _factory,
        address _treasury,
        uint256 _challengeFee,
        uint256 _protocolCutBps,
        uint256 _minWager
    ) Ownable(msg.sender) {
        factory = _factory;
        treasury = _treasury;
        challengeFee = _challengeFee;
        protocolCutBps = _protocolCutBps;
        minWager = _minWager;
        acceptanceWindow = 86400; // 24 hours
    }

    receive() external payable {}

    // ─── Core ──────────────────────────────────────────────────────────

    /// @notice Declare a battle: challenger vault vs defender vault
    /// @param challengerVault The challenger's vault
    /// @param defenderVault The vault being challenged
    /// @param duration Battle duration in seconds (1 hour – 7 days)
    function declareBattleForVault(
        address challengerVault,
        address defenderVault,
        uint256 duration
    ) external payable nonReentrant returns (uint256 battleId) {
        // Validate vaults
        if (!IVaultFactory(factory).isRegisteredVault(challengerVault)) revert InvalidVault();
        if (!IVaultFactory(factory).isRegisteredVault(defenderVault)) revert InvalidVault();

        // Only vault creator can declare
        if (IDripVault(challengerVault).creator() != msg.sender) revert NotChallenger();

        // Both need >= 2 depositors
        if (IDripVault(challengerVault).depositorCount() < 2) revert InvalidVault();
        if (IDripVault(defenderVault).depositorCount() < 2) revert InvalidVault();

        // Challenger cannot have an active battle (defender checked on accept, not here)
        if (vaultActiveBattle[challengerVault] != 0) revert BattleInProgress();

        // Duration: 1 hour to 7 days
        if (duration < 3600 || duration > 604800) revert InvalidVault();

        // msg.value = challengeFee + wagerAmount
        if (msg.value < challengeFee ) revert InsufficientChallengeFee();
        uint256 wagerAmount = msg.value - challengeFee;
        if (wagerAmount < minWager) revert InsufficientStake();

        // Send challenge fee to treasury immediately (non-refundable)
        (bool s, ) = payable(treasury).call{value: challengeFee}("");
        if (!s) revert TransferFailed();

        // Snapshot challenger PPS
        uint256 challengerPPS = _getVaultPPS(challengerVault);

        battleId = ++battleCount;
        Battle storage b = battles[battleId];
        b.challengerVault = challengerVault;
        b.defenderVault = defenderVault;
        b.challengerStake = wagerAmount;
        b.startPPS_challenger = challengerPPS;
        b.declaredAt = block.timestamp;
        b.endTime = block.timestamp + acceptanceWindow + duration; // tentative

        totalActiveStakes += wagerAmount;
        vaultActiveBattle[challengerVault] = battleId;

        emit BattleDeclared(battleId, challengerVault, defenderVault, b.endTime);
    }

    /// @notice Defender accepts battle (must match wager)
    function acceptBattle(uint256 battleId) external payable nonReentrant {
        Battle storage b = battles[battleId];
        if (b.challengerVault == address(0)) revert BattleNotFound();
        if (b.settled) revert AlreadySettled();
        if (b.defenderStake > 0) revert BattleAlreadyAccepted();

        // Only defender vault creator can accept
        if (IDripVault(b.defenderVault).creator() != msg.sender) revert NotDefenderCreator();

        // Defender vault must not already be in another active battle
        if (vaultActiveBattle[b.defenderVault] != 0) revert BattleInProgress();

        // Must match challenger's wager exactly; refund excess
        if (msg.value < b.challengerStake) revert InsufficientStake();

        b.defenderStake = b.challengerStake;
        b.startPPS_defender = _getVaultPPS(b.defenderVault);
        b.startTime = block.timestamp;
        b.endTime = block.timestamp + (b.endTime - b.declaredAt - acceptanceWindow);
        totalActiveStakes += b.defenderStake;
        vaultActiveBattle[b.defenderVault] = battleId;

        // Refund excess payment
        if (msg.value > b.challengerStake) {
            (bool rs, ) = payable(msg.sender).call{value: msg.value - b.challengerStake}("");
            if (!rs) revert TransferFailed();
        }

        emit BattleAccepted(battleId, b.defenderVault, block.timestamp);
    }

    /// @notice Cancel a battle if defender hasn't accepted within 24h
    function cancelPendingBattle(uint256 battleId) external nonReentrant {
        Battle storage b = battles[battleId];
        if (b.challengerVault == address(0)) revert BattleNotFound();
        if (b.settled) revert AlreadySettled();

        // Only challenger can cancel
        if (IDripVault(b.challengerVault).creator() != msg.sender) revert NotChallenger();

        // Can't cancel if already accepted
        if (b.defenderStake > 0) revert BattleAlreadyAccepted();

        // Acceptance window must have expired
        if (block.timestamp <= b.declaredAt + acceptanceWindow) revert AcceptanceWindowOpen();

        // Refund challenger's wager (challenge fee stays with treasury)
        uint256 refund = b.challengerStake;
        b.settled = true;
        totalActiveStakes -= refund;
        vaultActiveBattle[b.challengerVault] = 0;

        (bool s, ) = payable(msg.sender).call{value: refund}("");
        if (!s) revert TransferFailed();

        emit BattleCancelled(battleId, refund);
    }

    /// @notice Settle a battle after endTime
    function settleBattle(uint256 battleId) external nonReentrant {
        Battle storage b = battles[battleId];
        if (b.challengerVault == address(0)) revert BattleNotFound();
        if (b.settled) revert AlreadySettled();

        // If never accepted, refund challenger
        if (b.defenderStake == 0) {
            if (block.timestamp <= b.declaredAt + acceptanceWindow) revert AcceptanceWindowOpen();
            b.settled = true;
            totalActiveStakes -= b.challengerStake;
            vaultActiveBattle[b.challengerVault] = 0;

            (bool s, ) = payable(IDripVault(b.challengerVault).creator()).call{value: b.challengerStake}("");
            if (!s) revert TransferFailed();

            emit BattleCancelled(battleId, b.challengerStake);
            return;
        }

        if (block.timestamp < b.endTime) revert BattleNotEnded();

        b.settled = true;
        totalActiveStakes -= (b.challengerStake + b.defenderStake);
        vaultActiveBattle[b.challengerVault] = 0;
        vaultActiveBattle[b.defenderVault] = 0;

        // Calculate PPS growth
        uint256 challengerGrowth = _calculateGrowth(b.startPPS_challenger, b.challengerVault);
        uint256 defenderGrowth = _calculateGrowth(b.startPPS_defender, b.defenderVault);

        // Challenger wins on tie
        address winnerVault = defenderGrowth > challengerGrowth ? b.defenderVault : b.challengerVault;
        b.winner = winnerVault;

        uint256 combined = b.challengerStake + b.defenderStake;
        uint256 protocolFee = combined * protocolCutBps / 10000;
        uint256 winnerPayout = combined - protocolFee;

        address winnerCreator = IDripVault(winnerVault).creator();

        // Pay winner
        (bool s1, ) = payable(winnerCreator).call{value: winnerPayout}("");
        if (!s1) revert TransferFailed();

        // Pay treasury
        (bool s2, ) = payable(treasury).call{value: protocolFee}("");
        if (!s2) revert TransferFailed();

        emit BattleSettled(battleId, winnerVault, winnerPayout, protocolFee);
    }

    // ─── Internal ──────────────────────────────────────────────────────

    function _getVaultPPS(address vault) internal view returns (uint256) {
        uint256 totalAssets = IDripVault(vault).totalAssets();
        address token = IDripVault(vault).dripToken();
        uint256 totalSupply = IDripToken(token).totalSupply();
        if (totalSupply == 0) return 0;
        return totalAssets * 1e18 / totalSupply;
    }

    function _calculateGrowth(uint256 startPPS, address vault) internal view returns (uint256) {
        uint256 currentPPS = _getVaultPPS(vault);
        if (startPPS == 0 || currentPPS <= startPPS) return 0;
        return (currentPPS - startPPS) * 10000 / startPPS;
    }

    // ─── Admin ─────────────────────────────────────────────────────────

    /// @notice Update treasury address
    function setTreasuryAddress(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    /// @notice Withdraw unreserved funds (does not touch active battle wagers)
    function withdrawFees() external onlyOwner {
        uint256 withdrawable = address(this).balance > totalActiveStakes
            ? address(this).balance - totalActiveStakes
            : 0;
        if (withdrawable == 0) return;
        (bool s, ) = payable(treasury).call{value: withdrawable}("");
        if (!s) revert TransferFailed();
    }

    // ─── View ──────────────────────────────────────────────────────────

    /// @notice Check if a battle can be settled
    function canSettle(uint256 battleId) external view returns (bool) {
        Battle storage b = battles[battleId];
        if (b.challengerVault == address(0) || b.settled) return false;
        if (b.defenderStake == 0) return block.timestamp > b.declaredAt + acceptanceWindow;
        return block.timestamp >= b.endTime;
    }
}
