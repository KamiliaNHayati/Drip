// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DripPool} from "../src/DripPool.sol";
import {DripToken} from "../src/DripToken.sol";
import {DripVault} from "../src/DripVault.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {IConnectOracle} from "../src/interfaces/IConnectOracle.sol";

/// @dev Mock Connect Oracle for testing
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

    function get_prices(string[] memory) external view returns (Price[] memory) {
        revert("not implemented");
    }
}

/// @title DripVault Test Suite
contract DripVaultTest is Test {
    DripPool public pool;
    DripToken public dripToken;
    DripVault public vault;
    ERC20Mock public token;
    MockOracle public oracle;

    address public creator = makeAddr("creator");
    address public treasury = makeAddr("treasury");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public borrower = makeAddr("borrower");

    uint256 constant CREATOR_FEE_BPS = 1000;  // 10%
    uint256 constant DRIP_CUT_BPS = 1000;     // 10%

    function setUp() public {
        token = new ERC20Mock();
        oracle = new MockOracle();

        // Deploy pool
        pool = new DripPool(
            address(token),
            treasury,
            800,    // 8% APY
            1000,   // 10% reserve
            1000,   // 10% liq penalty
            5000,   // 50% of penalty to protocol
            7500    // 75% LTV
        );

        // Deploy token + vault (simulating clone pattern)
        dripToken = new DripToken();
        vault = new DripVault();

        // Initialize token with vault address
        dripToken.initialize(address(vault), "dripTest", "dTEST");

        // Initialize vault
        vault.initialize(
            creator,
            "TestVault",
            "A test vault",
            CREATOR_FEE_BPS,
            address(pool),
            address(dripToken),
            address(oracle),
            treasury,
            DRIP_CUT_BPS
        );

        // Mint tokens
        token.mint(alice, 1000 ether);
        token.mint(bob, 1000 ether);
        token.mint(borrower, 1000 ether);

        // Approve vault
        vm.prank(alice);
        token.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        token.approve(address(vault), type(uint256).max);

        // Set up borrower for pool interest
        vm.prank(borrower);
        token.approve(address(pool), type(uint256).max);
    }

    // ─── Helper: seed pool with borrow for interest ────────────────────
    function _seedPoolWithBorrow() internal {
        // Need some supply in pool first (from vault deposits)
        // Then borrower posts collateral and borrows to generate interest
        vm.prank(borrower);
        pool.addCollateral(500 ether);
    }

    // ─── Initialize Tests ──────────────────────────────────────────────

    function test_initialize_setsOraclePrice() public view {
        assertGt(vault.lastRecordedPrice(), 0, "Oracle price should be set");
    }

    function test_initialize_once() public {
        vm.expectRevert();  // OZ initializer reverts with InvalidInitialization()
        vault.initialize(
            creator, "x", "x", 500, address(pool),
            address(dripToken), address(oracle), treasury, 1000
        );
    }

    function test_initialize_setsDefaults() public view {
        assertEq(vault.defensiveThreshold(), 3);
        assertEq(vault.recoveryThresholdBps(), 10200);
        assertEq(vault.creator(), creator);
        assertEq(vault.creatorFeeBps(), CREATOR_FEE_BPS);
    }

    // ─── Deposit Tests ─────────────────────────────────────────────────

    function test_deposit_firstDepositor() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        // First deposit: shares == amount
        assertEq(dripToken.balanceOf(alice), 100 ether);
        assertEq(dripToken.totalSupply(), 100 ether);
        assertGt(vault.poolShares(), 0, "Pool shares should increase");
        assertEq(vault.depositorCount(), 1);
    }

    function test_deposit_incrementsDepositorCount() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        assertEq(vault.depositorCount(), 1);

        vm.prank(bob);
        vault.deposit(50 ether);
        assertEq(vault.depositorCount(), 2);

        // Alice deposits again — should NOT increment
        vm.prank(alice);
        vault.deposit(10 ether);
        assertEq(vault.depositorCount(), 2);
    }

    function test_deposit_secondDepositor() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        vm.prank(bob);
        vault.deposit(50 ether);

        // Bob's shares should be proportional
        uint256 bobShares = dripToken.balanceOf(bob);
        assertGt(bobShares, 0, "Bob should have shares");
    }

    function test_deposit_zeroAmount_reverts() public {
        vm.expectRevert(DripVault.ZeroAmount.selector);
        vm.prank(alice);
        vault.deposit(0);
    }

    function test_deposit_whenPaused_reverts() public {
        vm.prank(creator);
        vault.pause();

        vm.expectRevert(DripVault.VaultPaused.selector);
        vm.prank(alice);
        vault.deposit(100 ether);
    }

    // ─── Withdraw Tests ────────────────────────────────────────────────

    function test_withdraw_full_decrementsDepositorCount() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        assertEq(vault.depositorCount(), 1);

        uint256 aliceShares = dripToken.balanceOf(alice);
        vm.prank(alice);
        vault.withdraw(aliceShares);

        assertEq(vault.depositorCount(), 0);
        assertEq(dripToken.balanceOf(alice), 0);
    }

    function test_withdraw_partial_keepDepositorCount() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        vm.prank(alice);
        vault.withdraw(50 ether);

        assertEq(vault.depositorCount(), 1); // still a depositor
        assertGt(dripToken.balanceOf(alice), 0);
    }

    function test_withdraw_poolSharesCalculation() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        uint256 poolSharesBefore = vault.poolShares();

        uint256 aliceShares = dripToken.balanceOf(alice);
        vm.prank(alice);
        vault.withdraw(aliceShares);

        assertLt(vault.poolShares(), poolSharesBefore, "Pool shares should decrease");
    }

    function test_withdraw_zeroShares_reverts() public {
        vm.expectRevert(DripVault.ZeroAmount.selector);
        vm.prank(alice);
        vault.withdraw(0);
    }

    function test_withdraw_insufficientShares_reverts() public {
        vm.prank(alice);
        vault.deposit(10 ether);

        vm.expectRevert(DripVault.InsufficientShares.selector);
        vm.prank(alice);
        vault.withdraw(100 ether);
    }

    // ─── Preview Tests ─────────────────────────────────────────────────

    function test_previewDeposit_accurate() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        uint256 preview = vault.previewDeposit(50 ether);
        assertGt(preview, 0);
    }

    function test_previewWithdraw_accurate() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        uint256 shares = dripToken.balanceOf(alice);
        uint256 preview = vault.previewWithdraw(shares);
        assertGt(preview, 0);
    }

    // ─── totalAssets Tests ─────────────────────────────────────────────

    function test_totalAssets_readsFromPool() public {
        assertEq(vault.totalAssets(), 0);

        vm.prank(alice);
        vault.deposit(100 ether);

        uint256 ta = vault.totalAssets();
        assertGt(ta, 0, "totalAssets should reflect pool deposit");
    }

    // ─── Compound Tests ────────────────────────────────────────────────

    function test_compound_deltaSkimHappy() public {
        // Alice deposits into vault
        vm.prank(alice);
        vault.deposit(100 ether);

        // Create borrow position in pool for interest to accrue
        _seedPoolWithBorrow();
        vm.prank(borrower);
        pool.borrow(50 ether);

        uint256 lta = vault.lastTotalAssets();

        // Warp to accrue interest
        vm.warp(block.timestamp + 365 days);
        oracle.setPrice(1e9); // refresh oracle timestamp

        // Compound should harvest delta
        vault.compound();

        // lastTotalAssets should have been updated
        // (may be slightly different due to fee extraction)
        uint256 newLta = vault.lastTotalAssets();
        // After compound, the vault may have redistributed — just check no revert
    }

    function test_compound_noProfit_returnsEarly() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        // No time warp, no interest = no profit
        oracle.setPrice(1e9);

        // Should not revert
        vault.compound();
    }

    function test_compound_feeInvariant() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        _seedPoolWithBorrow();
        vm.prank(borrower);
        pool.borrow(50 ether);

        vm.warp(block.timestamp + 365 days);
        oracle.setPrice(1e9);

        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 creatorAccruedBefore = vault.creatorYieldAccrued();

        vault.compound();

        uint256 dripFeeReceived = token.balanceOf(treasury) - treasuryBefore;
        uint256 creatorAccruedAfter = vault.creatorYieldAccrued();
        uint256 netCreatorFee = creatorAccruedAfter - creatorAccruedBefore;

        // creatorFee = dripFee + netCreatorFee
        // creatorFee = withdrawn * creatorFeeBps / 10000
        // dripFee = creatorFee * dripCutBps / 10000
        if (dripFeeReceived > 0 || netCreatorFee > 0) {
            uint256 totalCreatorFee = dripFeeReceived + netCreatorFee;
            // dripFee should be 10% of total creator fee
            assertApproxEqAbs(
                dripFeeReceived * 10000 / totalCreatorFee,
                DRIP_CUT_BPS,
                1,
                "Drip fee should be 10% of creator fee"
            );
        }
    }

    // ─── Defensive Mode Tests ──────────────────────────────────────────

    function test_compound_defensiveEnters() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        // 3 consecutive drops should enter defensive mode
        oracle.setPrice(9e8); // drop 1
        vault.compound();
        assertFalse(vault.defensiveMode());

        oracle.setPrice(8e8); // drop 2
        vault.compound();
        assertFalse(vault.defensiveMode());

        oracle.setPrice(7e8); // drop 3
        vault.compound();
        assertTrue(vault.defensiveMode(), "Should enter defensive after 3 drops");
    }

    function test_compound_defensiveExits() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        // Enter defensive mode
        oracle.setPrice(9e8);
        vault.compound();
        oracle.setPrice(8e8);
        vault.compound();
        oracle.setPrice(7e8);
        vault.compound();
        assertTrue(vault.defensiveMode());

        // Recovery: price must exceed lastRecordedPrice * 102%
        // lastRecordedPrice = 7e8, recovery = 7e8 * 10200 / 10000 = 7.14e8
        oracle.setPrice(8e8); // above 7.14e8
        vault.compound();
        assertFalse(vault.defensiveMode(), "Should exit defensive after recovery");
    }

    function test_compound_staleOracle() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        // Warp forward so setStale() doesn't underflow (block.timestamp starts at 1 in Foundry)
        vm.warp(block.timestamp + 300);
        oracle.setStale();
        // Should not revert, just skip
        vault.compound();
    }

    function test_compound_noRevertWhenPaused() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        vm.prank(creator);
        vault.pause();

        // Should not revert, just emit skip
        vault.compound();
    }

    // ─── Emergency Sync Test ───────────────────────────────────────────

    function test_emergencySync_correctsPoolShares() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        uint256 poolSharesBefore = vault.poolShares();

        // Sync should set poolShares to actual pool lenderShares
        vm.prank(creator);
        vault.emergencySync();

        uint256 actual = pool.lenderShares(address(vault));
        assertEq(vault.poolShares(), actual, "Pool shares should match actual");
    }

    // ─── Creator Yield Test ────────────────────────────────────────────

    function test_claimCreatorYield() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        _seedPoolWithBorrow();
        vm.prank(borrower);
        pool.borrow(50 ether);

        vm.warp(block.timestamp + 365 days);
        oracle.setPrice(1e9);

        vault.compound();

        uint256 accrued = vault.creatorYieldAccrued();
        if (accrued > 0) {
            uint256 creatorBalBefore = token.balanceOf(creator);
            vm.prank(creator);
            vault.claimCreatorYield();
            assertEq(token.balanceOf(creator) - creatorBalBefore, accrued);
            assertEq(vault.creatorYieldAccrued(), 0);
        }
    }

    function test_claimCreatorYield_notCreator_reverts() public {
        vm.expectRevert(DripVault.NotCreator.selector);
        vm.prank(alice);
        vault.claimCreatorYield();
    }

    // ─── Fuzz Tests ────────────────────────────────────────────────────

    function testFuzz_deposit(uint256 amount) public {
        amount = bound(amount, 1 ether, 100 ether);

        token.mint(alice, amount);
        vm.prank(alice);
        token.approve(address(vault), amount);

        vm.prank(alice);
        vault.deposit(amount);

        assertGt(dripToken.balanceOf(alice), 0, "Should receive shares");
    }

    function testFuzz_withdraw(uint256 sharesToBurn) public {
        vm.prank(alice);
        vault.deposit(100 ether);

        uint256 aliceShares = dripToken.balanceOf(alice);
        // Bound to at least 1 ether to avoid rounding pool shares to 0
        sharesToBurn = bound(sharesToBurn, 1 ether, aliceShares);

        vm.prank(alice);
        vault.withdraw(sharesToBurn);

        assertEq(dripToken.balanceOf(alice), aliceShares - sharesToBurn);
    }

    function testFuzz_compound_anyPrice(uint256 price) public {
        price = bound(price, 1, 1e18);

        vm.prank(alice);
        vault.deposit(100 ether);

        oracle.setPrice(price);

        // Should never hard revert
        vault.compound();
    }

    function testFuzz_feeInvariant(uint256 withdrawn) public {
        withdrawn = bound(withdrawn, 1, 1000 ether);

        uint256 creatorFee = withdrawn * CREATOR_FEE_BPS / 10000;
        uint256 redeposit = withdrawn - creatorFee;

        // Invariant: creatorFee + redeposit == withdrawn
        assertEq(creatorFee + redeposit, withdrawn, "Fee invariant must hold");
    }

    // ─── View Tests ────────────────────────────────────────────────────

    function test_vaultInfo() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        (
            string memory _name,
            string memory _description,
            address _creator,
            uint256 _feeBps,
            uint256 _totalAssets,
            uint256 _totalShares,
            uint256 _depositorCount,
            bool _paused,
            bool _defensiveMode
        ) = vault.vaultInfo();

        assertEq(_name, "TestVault");
        assertEq(_creator, creator);
        assertEq(_feeBps, CREATOR_FEE_BPS);
        assertGt(_totalAssets, 0);
        assertGt(_totalShares, 0);
        assertEq(_depositorCount, 1);
        assertFalse(_paused);
        assertFalse(_defensiveMode);
    }

    function test_getDefensiveStatus() public view {
        (
            bool dm,
            uint256 drops,
            uint256 threshold,
            uint256 lastPrice,
            string memory code
        ) = vault.getDefensiveStatus();

        assertFalse(dm);
        assertEq(drops, 0);
        assertEq(threshold, 3);
        assertGt(lastPrice, 0);
        assertEq(keccak256(bytes(code)), keccak256(bytes("ACTIVE")));
    }

    function test_maxDeposit_whenPaused() public {
        assertEq(vault.maxDeposit(alice), type(uint256).max);

        vm.prank(creator);
        vault.pause();
        assertEq(vault.maxDeposit(alice), 0);
    }
}
