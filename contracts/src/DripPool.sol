// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title DripPool — Simple lending pool (yield source for Drip vaults)
/// @notice Single-asset INIT lending pool with interest accrual into share price
/// @dev Uses dead shares (1000 wei to address(0)) on first deposit to prevent inflation attack
contract DripPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ─── Events ────────────────────────────────────────────────────────
    event Supplied(address indexed lender, uint256 amount, uint256 shares);
    event Withdrawn(address indexed lender, uint256 shares, uint256 amount);
    event Borrowed(address indexed borrower, uint256 amount);
    event Repaid(address indexed borrower, uint256 amount);
    event InterestAccrued(uint256 totalInterest, uint256 protocolCut, uint256 lenderCut);
    event Liquidated(address indexed borrower, address indexed liquidator, uint256 debtCleared);
    event ReservesWithdrawn(address indexed to, uint256 amount);
    event EmergencyModeActivated();
    event EmergencyModeDeactivated();
    event TreasuryUpdated(address indexed newTreasury);

    // ─── Errors ────────────────────────────────────────────────────────
    error ZeroAmount();
    error InsufficientLiquidity();
    error InsufficientCollateral();
    error InsufficientShares();
    error EmergencyActive();
    error PositionHealthy();
    error InvalidParameter();
    error MinimumDeposit();

    // ─── Storage ───────────────────────────────────────────────────────
    IERC20 public asset;
    address public treasury;

    uint256 public interestRateBps;           // 800 = 8% APY
    uint256 public reserveFactorBps;          // 1000 = 10% of interest to protocol
    uint256 public liquidationPenaltyBps;     // 1000 = 10% total penalty
    uint256 public liquidationProtocolBps;    // 5000 = 50% of penalty to protocol (= 5% of debt)
    uint256 public collateralFactorBps;       // 7500 = 75% LTV max

    uint256 public totalDeposits;             // total owed to lenders (grows with interest)
    uint256 public totalBorrowed;
    uint256 public totalShares;               // lender shares (share price rises as interest accrues)
    uint256 public protocolReserves;          // accumulated protocol fees
    uint256 public lastAccrualTimestamp;
    bool public emergencyMode;

    mapping(address => uint256) public lenderShares;
    mapping(address => uint256) public borrowerDebt;       // debt at time of borrow (pre-index)
    mapping(address => uint256) public borrowerCollateral;
    uint256 public borrowIndex;                            // 1e18 = 1.0, grows with interest

    // ─── Constructor ───────────────────────────────────────────────────
    constructor(
        address _asset,
        address _treasury,
        uint256 _interestRateBps,
        uint256 _reserveFactorBps,
        uint256 _liquidationPenaltyBps,
        uint256 _liquidationProtocolBps,
        uint256 _collateralFactorBps
    ) Ownable(msg.sender) {
        if (_asset == address(0) || _treasury == address(0)) revert InvalidParameter();
        asset = IERC20(_asset);
        treasury = _treasury;
        interestRateBps = _interestRateBps;
        reserveFactorBps = _reserveFactorBps;
        liquidationPenaltyBps = _liquidationPenaltyBps;
        liquidationProtocolBps = _liquidationProtocolBps;
        collateralFactorBps = _collateralFactorBps;
        lastAccrualTimestamp = block.timestamp;
        borrowIndex = 1e18;
    }

    // ─── Admin ─────────────────────────────────────────────────────────

    /// @notice Update reserve factor (max 30%)
    function setReserveFactor(uint256 _bps) external onlyOwner {
        if (_bps > 3000) revert InvalidParameter();
        reserveFactorBps = _bps;
    }

    /// @notice Update collateral factor
    function setCollateralFactor(uint256 _bps) external onlyOwner {
        if (_bps > 9500) revert InvalidParameter();
        collateralFactorBps = _bps;
    }

    /// @notice Update treasury address
    function setTreasuryAddress(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert InvalidParameter();
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    /// @notice Withdraw accumulated protocol reserves to treasury
    function withdrawFees() external onlyOwner {
        uint256 amount = protocolReserves;
        if (amount == 0) revert ZeroAmount();
        protocolReserves = 0;
        asset.safeTransfer(treasury, amount);
        emit ReservesWithdrawn(treasury, amount);
    }

    /// @notice Activate emergency mode — blocks supply + borrow, allows withdraw
    function activateEmergency() external onlyOwner {
        emergencyMode = true;
        emit EmergencyModeActivated();
    }

    /// @notice Deactivate emergency mode
    function deactivateEmergency() external onlyOwner {
        emergencyMode = false;
        emit EmergencyModeDeactivated();
    }

    // ─── Core ──────────────────────────────────────────────────────────

    /// @notice Supply assets to the pool and receive shares
    function supply(uint256 amount) external nonReentrant returns (uint256 shares) {
        accrueInterest();
        if (emergencyMode) revert EmergencyActive();
        if (amount == 0) revert ZeroAmount();
        if (amount <= 1000) revert MinimumDeposit();

        if (totalShares == 0) {
            // First deposit: dead shares to prevent inflation attack
            shares = amount - 1000;
            totalShares = amount;
            totalDeposits += amount;
            lenderShares[address(0)] += 1000;
            lenderShares[msg.sender] += shares;
        } else {
            shares = amount * totalShares / totalDeposits;
            totalShares += shares;
            totalDeposits += amount;
            lenderShares[msg.sender] += shares;
        }

        asset.safeTransferFrom(msg.sender, address(this), amount);
        emit Supplied(msg.sender, amount, shares);
    }

    /// @notice Withdraw assets by burning shares
    function withdraw(uint256 shares) external nonReentrant returns (uint256 amount) {
        accrueInterest();
        if (shares == 0) revert ZeroAmount();
        if (shares > lenderShares[msg.sender]) revert InsufficientShares();

        amount = shares * totalDeposits / totalShares;

        uint256 available = asset.balanceOf(address(this)) - protocolReserves;
        if (amount > available) revert InsufficientLiquidity();

        lenderShares[msg.sender] -= shares;
        totalShares -= shares;
        totalDeposits -= amount;

        asset.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, shares, amount);
    }

    /// @notice Borrow assets from the pool (requires collateral)
    function borrow(uint256 amount) external nonReentrant {
        accrueInterest();
        if (emergencyMode) revert EmergencyActive();
        if (amount == 0) revert ZeroAmount();

        uint256 available = asset.balanceOf(address(this)) - protocolReserves;
        if (amount > available) revert InsufficientLiquidity();

        // Store debt as principal (pre-index)
        uint256 principal = amount * 1e18 / borrowIndex;
        borrowerDebt[msg.sender] += principal;
        totalBorrowed += amount;

        // Check collateral requirement using actual compounded debt
        uint256 actualDebt = getActualDebt(msg.sender);
        uint256 maxBorrow = borrowerCollateral[msg.sender] * collateralFactorBps / 10000;
        if (actualDebt > maxBorrow) revert InsufficientCollateral();

        asset.safeTransfer(msg.sender, amount);
        emit Borrowed(msg.sender, amount);
    }

    /// @notice Repay borrowed assets
    function repay(uint256 amount) external nonReentrant {
        accrueInterest();
        if (amount == 0) revert ZeroAmount();

        uint256 actualDebt = getActualDebt(msg.sender);
        if (amount > actualDebt) {
            amount = actualDebt;
        }

        // Convert repayment to principal reduction
        uint256 principalReduction = amount * 1e18 / borrowIndex;
        borrowerDebt[msg.sender] -= principalReduction;
        totalBorrowed -= amount;

        asset.safeTransferFrom(msg.sender, address(this), amount);
        emit Repaid(msg.sender, amount);
    }

    /// @notice Add collateral for borrowing
    function addCollateral(uint256 amount) external nonReentrant {
        accrueInterest();
        if (amount == 0) revert ZeroAmount();

        borrowerCollateral[msg.sender] += amount;
        asset.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Remove collateral (must maintain LTV)
    function removeCollateral(uint256 amount) external nonReentrant {
        accrueInterest();
        if (amount == 0) revert ZeroAmount();
        if (amount > borrowerCollateral[msg.sender]) revert InsufficientCollateral();

        uint256 newCollateral = borrowerCollateral[msg.sender] - amount;
        uint256 maxBorrow = newCollateral * collateralFactorBps / 10000;
        uint256 actualDebt = getActualDebt(msg.sender);
        if (actualDebt > maxBorrow) revert InsufficientCollateral();

        borrowerCollateral[msg.sender] = newCollateral;
        asset.safeTransfer(msg.sender, amount);
    }

    /// @notice Liquidate an unhealthy borrower position
    function liquidate(address borrower) external nonReentrant {
        accrueInterest();
        if (healthFactor(borrower) >= 10000) revert PositionHealthy();

        uint256 actualDebt = getActualDebt(borrower);
        uint256 collateral = borrowerCollateral[borrower];

        uint256 totalPenalty = actualDebt * liquidationPenaltyBps / 10000;
        uint256 protocolFee = totalPenalty * liquidationProtocolBps / 10000;
        uint256 liquidatorReward = totalPenalty - protocolFee;

        // Clear borrower position
        totalBorrowed -= actualDebt;
        borrowerDebt[borrower] = 0;
        borrowerCollateral[borrower] = 0;

        // Protocol fee from seized collateral
        protocolReserves += protocolFee;

        // Transfer liquidator reward from seized collateral
        asset.safeTransfer(msg.sender, liquidatorReward);

        // Return remaining collateral after debt repayment and penalties (if any left)
        uint256 totalCost = actualDebt + totalPenalty;
        if (collateral > totalCost) {
            asset.safeTransfer(borrower, collateral - totalCost);
        }

        emit Liquidated(borrower, msg.sender, actualDebt);
    }

    /// @notice Accrue interest on all borrowed positions
    function accrueInterest() public {
        uint256 elapsed = block.timestamp - lastAccrualTimestamp;
        if (elapsed == 0 || totalBorrowed == 0) return;

        uint256 totalInterest = totalBorrowed * interestRateBps * elapsed / (10000 * 365 days);
        uint256 protocolCut = totalInterest * reserveFactorBps / 10000;
        uint256 lenderCut = totalInterest - protocolCut;

        protocolReserves += protocolCut;
        totalDeposits += lenderCut;

        // Update borrow index so individual debts compound
        borrowIndex = borrowIndex * (totalBorrowed + totalInterest) / totalBorrowed;

        totalBorrowed += totalInterest;
        lastAccrualTimestamp = block.timestamp;

        emit InterestAccrued(totalInterest, protocolCut, lenderCut);
    }

    // ─── View ──────────────────────────────────────────────────────────

    /// @dev Simulate what totalDeposits would be after accruing pending interest
    function _simulatedTotalDeposits() internal view returns (uint256) {
        uint256 elapsed = block.timestamp - lastAccrualTimestamp;
        if (elapsed == 0 || totalBorrowed == 0) return totalDeposits;
        uint256 totalInterest = totalBorrowed * interestRateBps * elapsed / (10000 * 365 days);
        uint256 protocolCut = totalInterest * reserveFactorBps / 10000;
        return totalDeposits + (totalInterest - protocolCut);
    }

    /// @notice Preview how many shares a supply of `amount` would return
    function previewSupply(uint256 amount) external view returns (uint256 shares) {
        if (totalShares == 0) {
            return amount > 1000 ? amount - 1000 : 0;
        }
        shares = amount * totalShares / _simulatedTotalDeposits();
    }

    /// @notice Preview how many assets `shares` would return on withdrawal
    function previewWithdraw(uint256 shares) external view returns (uint256 amount) {
        if (totalShares == 0) return 0;
        amount = shares * _simulatedTotalDeposits() / totalShares;
    }

    /// @notice Current utilization rate in bps (10000 = 100%)
    function utilizationRate() external view returns (uint256) {
        if (totalDeposits == 0) return 0;
        return totalBorrowed * 10000 / totalDeposits;
    }

    /// @notice Health factor of a borrower in bps (10000 = 100% = at liquidation threshold)
    function healthFactor(address borrower) public view returns (uint256) {
        uint256 actualDebt = getActualDebt(borrower);
        if (actualDebt == 0) return type(uint256).max;
        uint256 maxBorrow = borrowerCollateral[borrower] * collateralFactorBps / 10000;
        return maxBorrow * 10000 / actualDebt;
    }

    /// @notice Get the actual compounded debt for a borrower (applies borrow index)
    function getActualDebt(address borrower) public view returns (uint256) {
        return borrowerDebt[borrower] * borrowIndex / 1e18;
    }
}
