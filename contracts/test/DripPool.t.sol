// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DripPool} from "../src/DripPool.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

/// @title DripPool Test Suite
contract DripPoolTest is Test {
    DripPool public pool;
    ERC20Mock public token;

    address public owner = address(this);
    address public treasury = makeAddr("treasury");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public liquidator = makeAddr("liquidator");

    uint256 constant INTEREST_RATE_BPS = 800;       // 8% APY
    uint256 constant RESERVE_FACTOR_BPS = 1000;     // 10%
    uint256 constant LIQ_PENALTY_BPS = 1000;        // 10%
    uint256 constant LIQ_PROTOCOL_BPS = 5000;       // 50% of penalty
    uint256 constant COLLATERAL_FACTOR_BPS = 7500;  // 75% LTV

    function setUp() public {
        token = new ERC20Mock();
        pool = new DripPool(
            address(token),
            treasury,
            INTEREST_RATE_BPS,
            RESERVE_FACTOR_BPS,
            LIQ_PENALTY_BPS,
            LIQ_PROTOCOL_BPS,
            COLLATERAL_FACTOR_BPS
        );

        // Mint tokens for test users
        token.mint(alice, 1000 ether);
        token.mint(bob, 1000 ether);
        token.mint(liquidator, 1000 ether);

        // Approve pool
        vm.prank(alice);
        token.approve(address(pool), type(uint256).max);
        vm.prank(bob);
        token.approve(address(pool), type(uint256).max);
        vm.prank(liquidator);
        token.approve(address(pool), type(uint256).max);
    }

    // ─── Supply Tests ──────────────────────────────────────────────────

    function test_supply() public {
        vm.prank(alice);
        uint256 shares = pool.supply(100 ether);

        // First deposit: shares = amount - 1000 (dead shares)
        assertEq(shares, 100 ether - 1000);
        assertEq(pool.lenderShares(alice), 100 ether - 1000);
        assertEq(pool.totalShares(), 100 ether);
        assertEq(pool.totalDeposits(), 100 ether);
        assertEq(pool.lenderShares(address(0)), 1000); // dead shares
    }

    function test_supply_secondDepositor() public {
        vm.prank(alice);
        pool.supply(100 ether);

        vm.prank(bob);
        uint256 bobShares = pool.supply(50 ether);

        assertEq(bobShares, 50 ether);
        assertEq(pool.lenderShares(bob), 50 ether);
        assertEq(pool.totalShares(), 150 ether);
        assertEq(pool.totalDeposits(), 150 ether);
    }

    function test_supply_belowMinimum_reverts() public {
        vm.expectRevert(DripPool.MinimumDeposit.selector);
        vm.prank(alice);
        pool.supply(1000); // exactly 1000, must be > 1000
    }

    function test_supply_zeroAmount_reverts() public {
        vm.expectRevert(DripPool.ZeroAmount.selector);
        vm.prank(alice);
        pool.supply(0);
    }

    // ─── Withdraw Tests ────────────────────────────────────────────────

    function test_withdraw() public {
        vm.prank(alice);
        uint256 shares = pool.supply(100 ether);

        vm.prank(alice);
        uint256 amount = pool.withdraw(shares);

        assertEq(amount, 100 ether - 1000);
        assertEq(pool.lenderShares(alice), 0);
    }

    function test_withdraw_zeroShares_reverts() public {
        vm.expectRevert(DripPool.ZeroAmount.selector);
        vm.prank(alice);
        pool.withdraw(0);
    }

    function test_withdraw_insufficientShares_reverts() public {
        vm.prank(alice);
        pool.supply(100 ether);

        vm.expectRevert(DripPool.InsufficientShares.selector);
        vm.prank(alice);
        pool.withdraw(200 ether);
    }

    // ─── Borrow + Repay Tests ──────────────────────────────────────────

    function test_borrow_and_repay() public {
        vm.prank(alice);
        pool.supply(100 ether);

        vm.prank(bob);
        pool.addCollateral(150 ether);
        vm.prank(bob);
        pool.borrow(80 ether);

        // borrowerDebt stores principal, getActualDebt returns compounded debt
        uint256 actualDebt = pool.getActualDebt(bob);
        assertEq(actualDebt, 80 ether); // borrowIndex is 1e18, so principal == actual
        assertEq(pool.borrowerCollateral(bob), 150 ether);
        assertEq(pool.totalBorrowed(), 80 ether);

        // Repay full debt
        vm.prank(bob);
        pool.repay(80 ether);

        assertEq(pool.getActualDebt(bob), 0);
        assertEq(pool.totalBorrowed(), 0);
    }

    function test_borrow_insufficientCollateral_reverts() public {
        vm.prank(alice);
        pool.supply(100 ether);

        vm.prank(bob);
        pool.addCollateral(10 ether);

        vm.expectRevert(DripPool.InsufficientCollateral.selector);
        vm.prank(bob);
        pool.borrow(80 ether);
    }

    function test_borrow_insufficientLiquidity_reverts() public {
        // Supply only a small amount
        vm.prank(alice);
        pool.supply(2 ether);

        // Bob adds huge collateral (supports large borrow)
        token.mint(bob, 10000 ether);
        vm.prank(bob);
        token.approve(address(pool), type(uint256).max);
        vm.prank(bob);
        pool.addCollateral(9000 ether);

        // Pool balance = 2 + 9000 = 9002 ether
        // Try to borrow more than pool balance
        vm.expectRevert(DripPool.InsufficientLiquidity.selector);
        vm.prank(bob);
        pool.borrow(9003 ether);
    }

    // ─── Interest Accrual Tests ────────────────────────────────────────

    function test_accrueInterest_splitCorrect() public {
        vm.prank(alice);
        pool.supply(100 ether);

        vm.prank(bob);
        pool.addCollateral(150 ether);
        vm.prank(bob);
        pool.borrow(80 ether);

        uint256 depositsBefore = pool.totalDeposits();
        uint256 reservesBefore = pool.protocolReserves();

        // Warp 1 year
        vm.warp(block.timestamp + 365 days);
        pool.accrueInterest();

        // totalInterest = 80e18 * 800 * 365days / (10000 * 365days) = 6.4e18
        uint256 expectedInterest = 80 ether * INTEREST_RATE_BPS / 10000;
        uint256 expectedProtocolCut = expectedInterest * RESERVE_FACTOR_BPS / 10000;
        uint256 expectedLenderCut = expectedInterest - expectedProtocolCut;

        assertEq(pool.protocolReserves() - reservesBefore, expectedProtocolCut);
        assertEq(pool.totalDeposits() - depositsBefore, expectedLenderCut);

        // split invariant
        assertEq(expectedProtocolCut + expectedLenderCut, expectedInterest);
    }

    function test_sharePrice_rises_after_interest() public {
        vm.prank(alice);
        uint256 shares = pool.supply(100 ether);

        vm.prank(bob);
        pool.addCollateral(150 ether);
        vm.prank(bob);
        pool.borrow(80 ether);

        uint256 valueBefore = pool.previewWithdraw(shares);

        vm.warp(block.timestamp + 365 days);
        pool.accrueInterest();

        uint256 valueAfter = pool.previewWithdraw(shares);
        assertGt(valueAfter, valueBefore, "Share price should rise after interest");
    }

    function test_borrowIndex_grows_with_interest() public {
        vm.prank(alice);
        pool.supply(100 ether);

        vm.prank(bob);
        pool.addCollateral(150 ether);
        vm.prank(bob);
        pool.borrow(80 ether);

        uint256 indexBefore = pool.borrowIndex();
        assertEq(indexBefore, 1e18);

        vm.warp(block.timestamp + 365 days);
        pool.accrueInterest();

        uint256 indexAfter = pool.borrowIndex();
        assertGt(indexAfter, indexBefore, "Borrow index should grow with interest");

        // Bob's actual debt should be higher than principal
        uint256 actualDebt = pool.getActualDebt(bob);
        assertGt(actualDebt, 80 ether, "Actual debt should grow with interest");
    }

    // ─── Liquidation Tests ─────────────────────────────────────────────

    function test_liquidate_unhealthy() public {
        vm.prank(alice);
        pool.supply(200 ether);

        // Bob posts tight collateral and borrows near max
        vm.prank(bob);
        pool.addCollateral(120 ether);
        vm.prank(bob);
        pool.borrow(80 ether); // 80/120 = 66.7%, LTV 75% max

        // Warp 5 years — interest compounds via borrowIndex, making position unhealthy
        vm.warp(block.timestamp + 365 days * 5);
        pool.accrueInterest();

        // Bob's actual debt should exceed collateral * 75%
        uint256 actualDebt = pool.getActualDebt(bob);
        assertGt(actualDebt, 90 ether, "Debt should have grown significantly");

        uint256 hf = pool.healthFactor(bob);
        assertLt(hf, 10000, "Bob should be unhealthy after 5 years");

        uint256 totalPenalty = actualDebt * LIQ_PENALTY_BPS / 10000;
        uint256 protocolFee = totalPenalty * LIQ_PROTOCOL_BPS / 10000;
        uint256 liquidatorReward = totalPenalty - protocolFee;

        uint256 liquidatorBalBefore = token.balanceOf(liquidator);
        uint256 reservesBefore = pool.protocolReserves();

        vm.prank(liquidator);
        pool.liquidate(bob);

        assertEq(pool.borrowerDebt(bob), 0, "Debt should be cleared");
        assertEq(pool.borrowerCollateral(bob), 0, "Collateral should be seized");
        assertEq(
            token.balanceOf(liquidator) - liquidatorBalBefore,
            liquidatorReward,
            "Liquidator should receive reward"
        );
        assertEq(
            pool.protocolReserves() - reservesBefore,
            protocolFee,
            "Protocol should receive fee"
        );
    }

    function test_liquidate_healthy_reverts() public {
        vm.prank(alice);
        pool.supply(100 ether);

        vm.prank(bob);
        pool.addCollateral(150 ether);
        vm.prank(bob);
        pool.borrow(10 ether);

        vm.expectRevert(DripPool.PositionHealthy.selector);
        vm.prank(liquidator);
        pool.liquidate(bob);
    }

    function test_liquidation_fee_split() public {
        vm.prank(alice);
        pool.supply(200 ether);

        vm.prank(bob);
        pool.addCollateral(120 ether);
        vm.prank(bob);
        pool.borrow(80 ether);

        // Warp to make unhealthy via borrowIndex
        vm.warp(block.timestamp + 365 days * 5);
        pool.accrueInterest();

        uint256 actualDebt = pool.getActualDebt(bob);
        uint256 totalPenalty = actualDebt * LIQ_PENALTY_BPS / 10000;
        uint256 protocolFee = totalPenalty * LIQ_PROTOCOL_BPS / 10000;
        uint256 liquidatorReward = totalPenalty - protocolFee;

        // Verify 50/50 split of 10% penalty
        assertEq(protocolFee, liquidatorReward, "Protocol and liquidator should split evenly");

        uint256 reservesBefore = pool.protocolReserves();
        uint256 liqBalBefore = token.balanceOf(liquidator);

        vm.prank(liquidator);
        pool.liquidate(bob);

        assertEq(pool.protocolReserves() - reservesBefore, protocolFee);
        assertEq(token.balanceOf(liquidator) - liqBalBefore, liquidatorReward);
    }

    // ─── Emergency Mode Tests ──────────────────────────────────────────

    function test_emergencyMode_blocksSupply() public {
        pool.activateEmergency();

        vm.expectRevert(DripPool.EmergencyActive.selector);
        vm.prank(alice);
        pool.supply(100 ether);
    }

    function test_emergencyMode_allowsWithdraw() public {
        vm.prank(alice);
        uint256 shares = pool.supply(100 ether);

        pool.activateEmergency();

        vm.prank(alice);
        uint256 amount = pool.withdraw(shares);
        assertGt(amount, 0, "Should be able to withdraw in emergency");
    }

    // ─── Admin Tests ───────────────────────────────────────────────────

    function test_withdrawFees_onlyOwner() public {
        vm.prank(alice);
        pool.supply(100 ether);
        vm.prank(bob);
        pool.addCollateral(150 ether);
        vm.prank(bob);
        pool.borrow(80 ether);

        vm.warp(block.timestamp + 365 days);
        pool.accrueInterest();

        uint256 reserves = pool.protocolReserves();
        assertGt(reserves, 0);

        // Non-owner cannot withdraw
        vm.expectRevert();
        vm.prank(alice);
        pool.withdrawFees();

        // Owner can withdraw
        uint256 treasuryBefore = token.balanceOf(treasury);
        pool.withdrawFees();
        assertEq(token.balanceOf(treasury) - treasuryBefore, reserves);
    }

    // ─── Inflation Attack Test ────────────────────────────────────────

    function test_inflationAttack_mitigated() public {
        vm.prank(alice);
        uint256 shares1 = pool.supply(2000);

        assertEq(pool.lenderShares(address(0)), 1000);
        assertEq(shares1, 1000);

        // Attacker donates directly to inflate share price
        vm.prank(alice);
        token.transfer(address(pool), 100 ether);

        // Victim deposits — donation doesn't affect totalDeposits
        vm.prank(bob);
        uint256 shares2 = pool.supply(50 ether);

        assertGt(shares2, 0, "Victim should receive shares");

        uint256 bobValue = pool.previewWithdraw(shares2);
        assertGt(bobValue, 49 ether, "Victim value should be close to deposit");
    }

    // ─── View Tests ────────────────────────────────────────────────────

    function test_utilizationRate() public {
        vm.prank(alice);
        pool.supply(100 ether);

        vm.prank(bob);
        pool.addCollateral(150 ether);
        vm.prank(bob);
        pool.borrow(80 ether);

        assertEq(pool.utilizationRate(), 8000);
    }

    function test_previewSupply_and_previewWithdraw() public {
        vm.prank(alice);
        pool.supply(100 ether);

        uint256 previewShares = pool.previewSupply(50 ether);
        assertEq(previewShares, 50 ether);

        uint256 aliceShares = pool.lenderShares(alice);
        uint256 previewAmount = pool.previewWithdraw(aliceShares);
        assertGt(previewAmount, 99 ether);
    }

    function test_healthFactor_noDebt() public view {
        assertEq(pool.healthFactor(alice), type(uint256).max);
    }

    // ─── Fuzz Tests ────────────────────────────────────────────────────

    function testFuzz_supply(uint256 amount) public {
        amount = bound(amount, 1001, 100 ether);

        token.mint(alice, amount);
        vm.prank(alice);
        token.approve(address(pool), amount);

        vm.prank(alice);
        uint256 shares = pool.supply(amount);

        assertGt(shares, 0, "Should receive shares");
        assertEq(pool.lenderShares(alice), shares);
    }

    function testFuzz_interestAccrual(uint256 elapsed) public {
        elapsed = bound(elapsed, 1, 365 days * 10);

        vm.prank(alice);
        pool.supply(100 ether);

        vm.prank(bob);
        pool.addCollateral(150 ether);
        vm.prank(bob);
        pool.borrow(80 ether);

        vm.warp(block.timestamp + elapsed);

        // Should not overflow
        pool.accrueInterest();

        assertGe(pool.totalDeposits(), 100 ether);
    }

    // ─── Collateral Tests ──────────────────────────────────────────────

    function test_addCollateral() public {
        vm.prank(bob);
        pool.addCollateral(100 ether);

        assertEq(pool.borrowerCollateral(bob), 100 ether);
    }

    function test_removeCollateral() public {
        vm.prank(bob);
        pool.addCollateral(100 ether);

        vm.prank(bob);
        pool.removeCollateral(50 ether);

        assertEq(pool.borrowerCollateral(bob), 50 ether);
    }

    function test_removeCollateral_wouldBreakLTV_reverts() public {
        vm.prank(alice);
        pool.supply(100 ether);

        vm.prank(bob);
        pool.addCollateral(150 ether);
        vm.prank(bob);
        pool.borrow(80 ether);

        vm.expectRevert(DripPool.InsufficientCollateral.selector);
        vm.prank(bob);
        pool.removeCollateral(100 ether);
    }

    // ─── Partial Repay Test ────────────────────────────────────────────

    function test_repay_partial() public {
        vm.prank(alice);
        pool.supply(100 ether);

        vm.prank(bob);
        pool.addCollateral(150 ether);
        vm.prank(bob);
        pool.borrow(80 ether);

        // Partial repay
        vm.prank(bob);
        pool.repay(30 ether);
        uint256 remainingDebt = pool.getActualDebt(bob);
        assertApproxEqAbs(remainingDebt, 50 ether, 1, "Remaining debt ~50 INIT");

        // Repay more than debt — should cap
        vm.prank(bob);
        pool.repay(100 ether);
        assertEq(pool.getActualDebt(bob), 0);
    }


    // ─── Accrue Edge Cases ────────────────────────────────────────────

    function test_accrueInterest_noElapsedTime() public {
        vm.prank(alice);
        pool.supply(100 ether);

        vm.prank(bob);
        pool.addCollateral(150 ether);
        vm.prank(bob);
        pool.borrow(50 ether);

        uint256 depositsBefore = pool.totalDeposits();
        // Accrue again in the same block — no new interest
        pool.accrueInterest();
        assertEq(pool.totalDeposits(), depositsBefore);
    }

    function test_accrueInterest_noDebt() public {
        vm.prank(alice);
        pool.supply(100 ether);

        uint256 depositsBefore = pool.totalDeposits();
        vm.warp(block.timestamp + 1 days);
        pool.accrueInterest();
        // No borrowing = no interest
        assertEq(pool.totalDeposits(), depositsBefore);
    }

    // ─── View Functions ───────────────────────────────────────────────

    function test_getActualDebt_withInterest() public {
        vm.prank(alice);
        pool.supply(100 ether);

        vm.prank(bob);
        pool.addCollateral(150 ether);
        vm.prank(bob);
        pool.borrow(50 ether);

        assertEq(pool.getActualDebt(bob), 50 ether);

        vm.warp(block.timestamp + 365 days);
        pool.accrueInterest();

        // Debt should have grown with interest
        assertGt(pool.getActualDebt(bob), 50 ether);
    }

    // ─── Admin ────────────────────────────────────────────────────────

    function test_setReserveFactor() public {
        pool.setReserveFactor(2000); // 20%
        assertEq(pool.reserveFactorBps(), 2000);
    }

    function test_setReserveFactor_tooHigh_reverts() public {
        vm.expectRevert(DripPool.InvalidParameter.selector);
        pool.setReserveFactor(3001);
    }

    function test_setCollateralFactor() public {
        pool.setCollateralFactor(8000); // 80%
        assertEq(pool.collateralFactorBps(), 8000);
    }

    function test_setCollateralFactor_tooHigh_reverts() public {
        vm.expectRevert(DripPool.InvalidParameter.selector);
        pool.setCollateralFactor(9501);
    }

    function test_setTreasuryAddress() public {
        address newTreasury = makeAddr("newTreasury");
        pool.setTreasuryAddress(newTreasury);
        assertEq(pool.treasury(), newTreasury);
    }

    function test_setTreasuryAddress_zero_reverts() public {
        vm.expectRevert(DripPool.InvalidParameter.selector);
        pool.setTreasuryAddress(address(0));
    }

    function test_deactivateEmergency() public {
        pool.activateEmergency();
        assertTrue(pool.emergencyMode());

        pool.deactivateEmergency();
        assertFalse(pool.emergencyMode());
    }

    function test_borrow_emergencyMode_reverts() public {
        vm.prank(alice);
        pool.supply(100 ether);

        vm.prank(bob);
        pool.addCollateral(200 ether);

        pool.activateEmergency();

        vm.expectRevert(DripPool.EmergencyActive.selector);
        vm.prank(bob);
        pool.borrow(50 ether);
    }

    function test_constructor_InvalidParameters() public {
        // Line 69: Test constructor revert if asset is address(0)
        vm.expectRevert(DripPool.InvalidParameter.selector);
        new DripPool(address(0), treasury, 800, 1000, 1000, 5000, 7500);

        // Line 69: Test constructor revert if treasury is address(0)
        vm.expectRevert(DripPool.InvalidParameter.selector);
        new DripPool(address(token), address(0), 800, 1000, 1000, 5000, 7500);
    }

    function test_withdrawFees_ZeroAmount() public {
        // Line 105: Test withdrawFees revert when reserves are 0
        vm.prank(address(this)); // Owner is the test contract
        vm.expectRevert(DripPool.ZeroAmount.selector);
        pool.withdrawFees();
    }

        function test_withdraw_InsufficientLiquidity() public {
        // Line 159: Test withdraw revert when liquidity is insufficient
        // We need: withdrawal amount > available cash
        // available cash = balance - reserves.
        
        // 1. Alice supplies 100 ether
        vm.prank(alice);
        pool.supply(100 ether);

        // 2. Bob adds collateral and borrows heavily
        vm.prank(bob);
        pool.addCollateral(150 ether);
        vm.prank(bob);
        pool.borrow(112 ether); // 75% LTV (150 * 0.75 = 112.5)

        // At this point:
        // Balance = 100 (Alice) + 150 (Bob Collateral) - 112 (Bob Borrow) = 138 ether
        // Available = 138 ether (reserves are 0)
        // Alice's claim is ~100 ether. 100 < 138, so withdraw would pass.
        // We need to increase Alice's claim AND decrease available cash.

        // 3. Warp time to accrue interest.
        // Interest increases totalDeposits (Alice's claim grows).
        // Interest increases protocolReserves (Available cash decreases because reserves are locked).
        vm.warp(block.timestamp + 365 days * 10); // 10 years
        pool.accrueInterest();

        // 4. Alice tries to withdraw her full claim.
        // The amount calculated will be significantly higher than the cash available in the pool.
        uint256 aliceShares = pool.lenderShares(alice);
        vm.prank(alice);
        vm.expectRevert(DripPool.InsufficientLiquidity.selector);
        pool.withdraw(aliceShares);
    }

    function test_borrow_ZeroAmount() public {
        // Line 173: Test borrow revert for 0 amount
        vm.prank(bob);
        vm.expectRevert(DripPool.ZeroAmount.selector);
        pool.borrow(0);
    }

    function test_repay_ZeroAmount() public {
        // Line 195: Test repay revert for 0 amount
        vm.prank(bob);
        vm.expectRevert(DripPool.ZeroAmount.selector);
        pool.repay(0);
    }

    function test_addCollateral_ZeroAmount() public {
        // Line 214: Test addCollateral revert for 0 amount
        vm.prank(bob);
        vm.expectRevert(DripPool.ZeroAmount.selector);
        pool.addCollateral(0);
    }

    function test_removeCollateral_ZeroAmount() public {
        // Line 223: Test removeCollateral revert for 0 amount
        vm.prank(bob);
        vm.expectRevert(DripPool.ZeroAmount.selector);
        pool.removeCollateral(0);
    }

    function test_liquidate_CollateralSurplus() public {
        // Line 260: Test liquidation where collateral > debt + penalty
        // This triggers the branch returning remaining collateral to the borrower

        // 1. Setup liquidity
        vm.prank(alice);
        pool.supply(100 ether);

        // 2. Bob borrows near max. Collateral 100, Borrow 74 (Max 75)
        vm.prank(bob);
        pool.addCollateral(100 ether);
        vm.prank(bob);
        pool.borrow(74 ether);

        // 3. Warp time to make position unhealthy
        // 365 days at 8% APY adds ~6 ether interest. Debt ~80. Max borrow 75.
        vm.warp(block.timestamp + 365 days);
        pool.accrueInterest();

        // Verify unhealthy
        assertLt(pool.healthFactor(bob), 10000);

        uint256 bobBalBefore = token.balanceOf(bob);

        // 4. Liquidate
        vm.prank(liquidator);
        pool.liquidate(bob);

        // 5. Verify Bob received excess collateral
        // Debt ~80, Penalty ~8. Total cost ~88. Collateral 100. Excess ~12.
        assertGt(token.balanceOf(bob), bobBalBefore, "Bob should receive excess collateral");
    }

    function test_previewSupply_ZeroShares() public {
        // Line 301: Test previewSupply when totalShares == 0
        // Branch: amount <= 1000 (returns 0)
        uint256 shares = pool.previewSupply(500);
        assertEq(shares, 0, "Should return 0 for amount <= 1000");

        // Branch: amount > 1000 (returns amount - 1000)
        shares = pool.previewSupply(2000);
        assertEq(shares, 1000, "Should return amount - 1000");
    }

    function test_previewWithdraw_ZeroShares() public {
        // Line 309: Test previewWithdraw when totalShares == 0
        uint256 amount = pool.previewWithdraw(100);
        assertEq(amount, 0, "Should return 0 when totalShares is 0");
    }

    function test_utilizationRate_ZeroDeposits() public {
        // Line 315: Test utilizationRate when totalDeposits == 0
        uint256 rate = pool.utilizationRate();
        assertEq(rate, 0, "Utilization should be 0 when deposits are 0");
    }
}
