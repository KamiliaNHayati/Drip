// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IConnectOracle} from "./interfaces/IConnectOracle.sol";
import {IDripPool} from "./interfaces/IDripPool.sol";
import {IDripToken} from "./interfaces/IDripToken.sol";
import {IGhostRegistry} from "./interfaces/IGhostRegistry.sol";

/// @title DripVault — Social yield vault (EIP-1167 clone)
/// @notice Deposits into DripPool, auto-compounds yield via delta skim, tracks creator fees.
/// @dev Uses OwnableUpgradeable for clone compatibility. No shares mapping — uses DripToken.
contract DripVault is OwnableUpgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ─── Events ────────────────────────────────────────────────────────
    event Initialized(address indexed creator, string name);
    event Deposited(address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, uint256 shares, uint256 amount);
    event Compounded(uint256 profit, uint256 creatorFee, uint256 dripFee, uint256 redeposited);
    event CompoundSkipped(uint256 consecutiveDrops, string reason);
    event DefensiveModeEntered(uint256 price, uint256 consecutiveDrops);
    event DefensiveModeExited(uint256 price);
    event CreatorFeeAccrued(address indexed creator, uint256 amount);
    event EmergencySynced(uint256 oldPoolShares, uint256 newPoolShares);
    event GhostDelegated(address indexed ghost, address indexed registry);
    event GhostUndelegated();

    // ─── Errors ────────────────────────────────────────────────────────
    error ZeroAmount();
    error InsufficientShares();
    error VaultPaused();
    error NotCreator();
    error InsufficientDelegationFee();
    error TransferFailed();

    // ─── Storage ───────────────────────────────────────────────────────
    address public creator;
    string public name;
    string public description;
    uint256 public creatorFeeBps;
    uint256 public dripCutBps;
    address public dripPool;
    address public dripToken;
    address public connectOracle;
    address public treasury;
    IERC20 public asset;

    // No shares mapping — use IDripToken(dripToken).balanceOf(user) directly
    // No totalShares — use IDripToken(dripToken).totalSupply() directly
    uint256 public poolShares;             // vault's shares in DripPool (source of truth)
    uint256 public lastTotalAssets;        // used for delta skim in compound()
    uint256 public depositorCount;         // tracks number of unique depositors

    uint256 public creatorYieldAccrued;

    // Oracle + defensive mode
    uint256 public lastRecordedPrice;      // initialized in initialize() via oracle call
    uint256 public consecutiveDropCount;
    uint256 public defensiveThreshold;     // default 3
    uint256 public recoveryThresholdBps;   // default 10200 (102%)
    bool public defensiveMode;
    bool public paused;

    // Ghost delegation (optional — set by creator)
    address public delegatedGhost;
    address public ghostRegistry;

    // ─── Initialize ────────────────────────────────────────────────────

    /// @notice Initialize the vault clone
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
    ) external initializer {
        __Ownable_init(_creator);

        creator = _creator;
        name = _name;
        description = _description;
        creatorFeeBps = _creatorFeeBps;
        dripPool = _dripPool;
        dripToken = _dripToken;
        connectOracle = _connectOracle;
        treasury = _treasury;
        dripCutBps = _dripCutBps;
        asset = IDripPool(_dripPool).asset();

        defensiveThreshold = 3;
        recoveryThresholdBps = 10200;

        // Set initial oracle price
        if (_connectOracle != address(0)) {
            try IConnectOracle(_connectOracle).get_price("INIT/USD") returns (IConnectOracle.Price memory p) {
                lastRecordedPrice = p.price;
            } catch {
                lastRecordedPrice = 0;
            }
        }

        emit Initialized(_creator, _name);
    }

    // ─── Core ──────────────────────────────────────────────────────────

    /// @notice Deposit INIT into the vault
    function deposit(uint256 amount) external nonReentrant {
        if (paused) revert VaultPaused();
        if (amount == 0) revert ZeroAmount();

        // Pull tokens from user
        asset.safeTransferFrom(msg.sender, address(this), amount);

        // Track depositor count
        uint256 currentBalance = IDripToken(dripToken).balanceOf(msg.sender);
        if (currentBalance == 0) {
            depositorCount++;
        }

        // Calculate shares
        uint256 supply = IDripToken(dripToken).totalSupply();
        uint256 _shares;
        if (supply == 0) {
            _shares = amount;
        } else {
            _shares = amount * supply / totalAssets();
        }

        // Deposit into pool
        asset.forceApprove(dripPool, amount);
        uint256 newPoolShares = IDripPool(dripPool).supply(amount);
        poolShares += newPoolShares;

        // Update tracking
        lastTotalAssets = totalAssets();

        // Mint receipt tokens
        IDripToken(dripToken).mint(msg.sender, _shares);

        emit Deposited(msg.sender, amount, _shares);
    }

    /// @notice Withdraw INIT from the vault by burning shares
    function withdraw(uint256 sharesToBurn) external nonReentrant {
        uint256 userBalance = IDripToken(dripToken).balanceOf(msg.sender);
        if (sharesToBurn == 0) revert ZeroAmount();
        if (sharesToBurn > userBalance) revert InsufficientShares();

        uint256 supply = IDripToken(dripToken).totalSupply();

        // Proportional pool shares to burn (matches user's share of the vault)
        uint256 poolSharesToWithdraw = sharesToBurn * poolShares / supply;

        // Burn BEFORE external calls (checks-effects-interactions)
        IDripToken(dripToken).burn(msg.sender, sharesToBurn);

        // Track depositor count
        if (sharesToBurn == userBalance) {
            depositorCount--;
        }

        // Withdraw from pool
        poolShares -= poolSharesToWithdraw;
        uint256 actualAssets = IDripPool(dripPool).withdraw(poolSharesToWithdraw);

        // Update tracking
        lastTotalAssets = totalAssets();

        // Transfer to user
        asset.safeTransfer(msg.sender, actualAssets);

        emit Withdrawn(msg.sender, sharesToBurn, actualAssets);
    }

    /// @notice Compound yield via delta skim — callable by anyone
    function compound() external nonReentrant {
        // Step 1: Check paused (compound never reverts, just returns)
        if (paused) {
            emit CompoundSkipped(consecutiveDropCount, "PAUSED");
            return;
        }

        // Step 2: Get oracle price
        if (connectOracle != address(0)) {
            try IConnectOracle(connectOracle).get_price("INIT/USD") returns (IConnectOracle.Price memory p) {
                // Step 3: Staleness check
                if (block.timestamp - p.timestamp > 60) {
                    emit CompoundSkipped(consecutiveDropCount, "STALE_ORACLE");
                    return;
                }

                // Step 4: Consecutive drop tracking
                if (p.price < lastRecordedPrice) {
                    consecutiveDropCount++;
                } else {
                    consecutiveDropCount = 0;
                    if (defensiveMode && p.price > lastRecordedPrice * recoveryThresholdBps / 10000) {
                        defensiveMode = false;
                        emit DefensiveModeExited(p.price);
                    }
                }

                // Step 5: Enter defensive if threshold reached
                if (consecutiveDropCount >= defensiveThreshold && !defensiveMode) {
                    defensiveMode = true;
                    emit DefensiveModeEntered(p.price, consecutiveDropCount);
                }

                // Step 6: Skip if defensive
                if (defensiveMode) {
                    lastRecordedPrice = p.price;
                    emit CompoundSkipped(consecutiveDropCount, "DEFENSIVE_MODE");
                    return;
                }

                lastRecordedPrice = p.price;
            } catch {
                emit CompoundSkipped(consecutiveDropCount, "ORACLE_ERROR");
                return;
            }
        }

        // Step 7: Delta Skim — calculate profit
        uint256 currentAssets = totalAssets();
        if (currentAssets <= lastTotalAssets) {
            return; // no profit to harvest
        }
        uint256 profit = currentAssets - lastTotalAssets;

        // Step 8: Withdraw profit from pool (proportional share calculation)
        uint256 poolSharesToWithdraw = profit * poolShares / currentAssets;
        if (poolSharesToWithdraw == 0) return;
        if (poolSharesToWithdraw > poolShares) poolSharesToWithdraw = poolShares;

        uint256 withdrawn = IDripPool(dripPool).withdraw(poolSharesToWithdraw);
        poolShares -= poolSharesToWithdraw;

        // Step 9: Fee math (invariant: creatorFee + redeposit == withdrawn)
        uint256 creatorFee = withdrawn * creatorFeeBps / 10000;
        uint256 dripFee = creatorFee * dripCutBps / 10000;
        uint256 netCreatorFee = creatorFee - dripFee;
        uint256 redeposit = withdrawn - creatorFee;

        // Step 10: Ghost stats tracking (no fee deduction — rewards are leaderboard-only for MVP)
        if (delegatedGhost != address(0) && msg.sender == delegatedGhost && ghostRegistry != address(0)) {
            try IGhostRegistry(ghostRegistry).recordCompound(msg.sender, profit) returns (uint256) {
            } catch {
            }
        }

        // Step 11: Distribute fees
        if (dripFee > 0) {
            asset.safeTransfer(treasury, dripFee);
        }
        creatorYieldAccrued += netCreatorFee;
        // netCreatorFee stays in vault's token balance — not re-deposited

        // Step 12: Re-deposit remainder into pool
        if (redeposit > 0) {
            asset.forceApprove(dripPool, redeposit);
            uint256 newPoolShares = IDripPool(dripPool).supply(redeposit);
            poolShares += newPoolShares;
        }

        // Step 13: Update tracking
        lastTotalAssets = totalAssets();

        emit Compounded(profit, creatorFee, dripFee, redeposit);
    }

    /// @notice Creator claims accrued yield
    function claimCreatorYield() external nonReentrant {
        if (msg.sender != creator) revert NotCreator();
        uint256 amount = creatorYieldAccrued;
        if (amount == 0) revert ZeroAmount();
        creatorYieldAccrued = 0;
        asset.safeTransfer(creator, amount);
        emit CreatorFeeAccrued(creator, amount);
    }

    /// @notice Creator sets a delegated ghost and registry for automated compounding
    /// @param ghost Ghost operator address (set to address(0) to undelegate)
    /// @param registry GhostRegistry contract address
    /// @dev Delegation fee: 5 INIT paid to treasury (per RULES.md). No fee for undelegation.
    function setDelegatedGhost(address ghost, address registry) external payable {
        if (msg.sender != creator) revert NotCreator();
        if (ghost != address(0)) {
            uint256 delegationFee = 5 ether;
            if (msg.value < delegationFee) revert InsufficientDelegationFee();
            (bool s, ) = payable(treasury).call{value: delegationFee}("");
            if (!s) revert TransferFailed();
            if (msg.value > delegationFee) {
                (bool r, ) = payable(msg.sender).call{value: msg.value - delegationFee}("");
                if (!r) revert TransferFailed();
            }
        }
        delegatedGhost = ghost;
        ghostRegistry = registry;
        if (ghost != address(0)) {
            emit GhostDelegated(ghost, registry);
        } else {
            emit GhostUndelegated();
        }
    }

    /// @notice Creator sets defensive threshold
    function setDefensiveThreshold(uint256 n) external {
        if (msg.sender != creator) revert NotCreator();
        defensiveThreshold = n;
    }

    /// @notice Creator resyncs poolShares to actual pool balance
    function emergencySync() external {
        if (msg.sender != creator) revert NotCreator();
        uint256 actual = IDripPool(dripPool).lenderShares(address(this));
        emit EmergencySynced(poolShares, actual);
        poolShares = actual;
        lastTotalAssets = totalAssets();
    }

    /// @notice Update treasury address (owner = vault creator via OwnableUpgradeable)
    function setTreasuryAddress(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    /// @notice Withdraw accumulated protocol/drip fees held in this vault to treasury
    function withdrawFees() external onlyOwner {
        uint256 bal = asset.balanceOf(address(this));
        uint256 owed = creatorYieldAccrued;
        if (bal <= owed) return;
        uint256 withdrawable = bal - owed;
        asset.safeTransfer(treasury, withdrawable);
    }

    /// @notice Pause deposits/withdrawals (owner only)
    function pause() external onlyOwner {
        paused = true;
    }

    /// @notice Unpause (owner only)
    function unpause() external onlyOwner {
        paused = false;
    }

    // ─── View ──────────────────────────────────────────────────────────

    /// @notice Total assets owned by depositors (reads from pool, excludes creator fees)
    function totalAssets() public view returns (uint256) {
        if (poolShares == 0) return 0;
        return IDripPool(dripPool).previewWithdraw(poolShares);
    }

    /// @notice Preview shares for a deposit amount
    function previewDeposit(uint256 amount) external view returns (uint256 sharesOut) {
        uint256 supply = IDripToken(dripToken).totalSupply();
        if (supply == 0) return amount;
        return amount * supply / totalAssets();
    }

    /// @notice Preview assets for a withdrawal
    function previewWithdraw(uint256 sharesToBurn) external view returns (uint256 assetsOut) {
        uint256 supply = IDripToken(dripToken).totalSupply();
        if (supply == 0) return 0;
        return sharesToBurn * totalAssets() / supply;
    }

    /// @notice Max deposit (unlimited unless paused)
    function maxDeposit(address) external view returns (uint256) {
        if (paused) return 0;
        return type(uint256).max;
    }

    /// @notice Max withdrawable amount for a user
    function maxWithdraw(address user) external view returns (uint256) {
        uint256 userShares = IDripToken(dripToken).balanceOf(user);
        if (userShares == 0) return 0;
        uint256 supply = IDripToken(dripToken).totalSupply();
        return userShares * totalAssets() / supply;
    }

    /// @notice Get user's shares
    function getSharesOf(address user) external view returns (uint256) {
        return IDripToken(dripToken).balanceOf(user);
    }

    /// @notice Get defensive mode status
    function getDefensiveStatus() external view returns (
        bool _defensiveMode,
        uint256 _consecutiveDrops,
        uint256 _threshold,
        uint256 _lastPrice,
        string memory _statusCode
    ) {
        _defensiveMode = defensiveMode;
        _consecutiveDrops = consecutiveDropCount;
        _threshold = defensiveThreshold;
        _lastPrice = lastRecordedPrice;

        if (defensiveMode) {
            _statusCode = "DEFENSIVE_MODE";
        } else if (lastRecordedPrice == 0) {
            _statusCode = "STALE_ORACLE";
        } else {
            _statusCode = "ACTIVE";
        }
    }

    /// @notice Get vault summary info
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
    ) {
        _name = name;
        _description = description;
        _creator = creator;
        _creatorFeeBps = creatorFeeBps;
        _totalAssets = totalAssets();
        _totalShares = IDripToken(dripToken).totalSupply();
        _depositorCount = depositorCount;
        _paused = paused;
        _defensiveMode = defensiveMode;
    }
}
