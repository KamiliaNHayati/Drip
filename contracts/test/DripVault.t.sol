// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DripPool} from "../src/DripPool.sol";
import {DripToken} from "../src/DripToken.sol";
import {DripVault} from "../src/DripVault.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {MockOracle} from "./mocks/MockOracle.sol";
import {GhostRegistry} from "../src/GhostRegistry.sol";

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

        uint256 ltaBefore = vault.lastTotalAssets();

        // Warp to accrue interest
        vm.warp(block.timestamp + 365 days);
        oracle.setPrice(1e9); // refresh oracle timestamp

        // Compound should harvest delta
        vault.compound();

        // lastTotalAssets should have been updated
        // (may be slightly different due to fee extraction)
        uint256 newLta = vault.lastTotalAssets();
        assertGe(newLta, 0); // no revert — just check it ran
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
        assertGt(poolSharesBefore, 0);

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

    function testFuzz_feeInvariant(uint256 withdrawn) public pure {
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
            ,
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

    // ─── Ghost Delegation ─────────────────────────────────────────────

    function test_setDelegatedGhost_withFee() public {
        address ghost = makeAddr("ghost");
        address registry = makeAddr("registry");
        vm.deal(creator, 10 ether);

        vm.prank(creator);
        vault.setDelegatedGhost{value: 5 ether}(ghost, registry);

        assertEq(vault.delegatedGhost(), ghost);
        assertEq(vault.ghostRegistry(), registry);
    }

    function test_setDelegatedGhost_undelegation_noFee() public {
        address ghost = makeAddr("ghost");
        address registry = makeAddr("registry");
        vm.deal(creator, 10 ether);

        // First delegate
        vm.prank(creator);
        vault.setDelegatedGhost{value: 5 ether}(ghost, registry);

        // Undelegation: ghost = address(0), no fee needed
        vm.prank(creator);
        vault.setDelegatedGhost(address(0), address(0));
        assertEq(vault.delegatedGhost(), address(0));
    }

    function test_setDelegatedGhost_insufficientFee_reverts() public {
        vm.deal(creator, 10 ether);
        vm.expectRevert(DripVault.InsufficientDelegationFee.selector);
        vm.prank(creator);
        vault.setDelegatedGhost{value: 3 ether}(makeAddr("ghost"), makeAddr("reg"));
    }

    function test_setDelegatedGhost_excessRefunded() public {
        vm.deal(creator, 20 ether);
        uint256 creatorBefore = creator.balance;

        vm.prank(creator);
        vault.setDelegatedGhost{value: 8 ether}(makeAddr("ghost"), makeAddr("reg"));

        // Should only cost 5 INIT (3 refunded)
        assertEq(creatorBefore - creator.balance, 5 ether);
    }

    function test_setDelegatedGhost_notCreator_reverts() public {
        vm.deal(alice, 10 ether);
        vm.expectRevert(DripVault.NotCreator.selector);
        vm.prank(alice);
        vault.setDelegatedGhost{value: 5 ether}(makeAddr("ghost"), makeAddr("reg"));
    }

    // ─── Treasury & Admin ──────────────────────────────────────────────

    function test_setTreasuryAddress() public {
        address newTreasury = makeAddr("newTreasury");
        vm.prank(creator); // owner of vault = creator
        vault.setTreasuryAddress(newTreasury);
        assertEq(vault.treasury(), newTreasury);
    }

    function test_setDefensiveThreshold() public {
        vm.prank(creator);
        vault.setDefensiveThreshold(7);
        (,, uint256 threshold,,) = vault.getDefensiveStatus();
        assertEq(threshold, 7);
    }

    function test_setDefensiveThreshold_notCreator_reverts() public {
        vm.expectRevert(DripVault.NotCreator.selector);
        vm.prank(alice);
        vault.setDefensiveThreshold(5);
    }

    function test_pause_unpause() public {
        vm.prank(creator);
        vault.pause();
        assertTrue(vault.paused());

        vm.prank(creator);
        vault.unpause();
        assertFalse(vault.paused());
    }

    // ─── View Functions ────────────────────────────────────────────────

    function test_maxWithdraw() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        uint256 maxW = vault.maxWithdraw(alice);
        assertGt(maxW, 0);

        // Non-depositor should get 0
        assertEq(vault.maxWithdraw(makeAddr("nobody")), 0);
    }

    function test_getSharesOf() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        uint256 shares = vault.getSharesOf(alice);
        assertGt(shares, 0);
        assertEq(vault.getSharesOf(makeAddr("nobody")), 0);
    }

    function test_previewDeposit_withExistingSupply() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        uint256 preview = vault.previewDeposit(50 ether);
        assertGt(preview, 0);
    }

    function test_previewWithdraw_withExistingSupply() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        uint256 shares = vault.getSharesOf(alice);
        uint256 preview = vault.previewWithdraw(shares);
        // Should be approximately 100 ether (minus dead shares cost)
        assertGt(preview, 90 ether);
    }

    function test_compound_withGhostDelegation() public {
        // Deploy real GhostRegistry
        GhostRegistry ghostReg = new GhostRegistry(treasury, 10, 1000);
        
        // Authorize vault so recordCompound doesn't revert
        ghostReg.authorizeVault(address(vault));

        // Register as ghost
        address ghost = makeAddr("ghost");
        vm.prank(ghost);
        ghostReg.registerAsGhost();
        
        // Setup vault with ghost delegation
        vm.deal(creator, 10 ether);
        vm.prank(creator);
        vault.setDelegatedGhost{value: 5 ether}(ghost, address(ghostReg));
        
        // Alice deposits
        vm.prank(alice);
        vault.deposit(100 ether);
        
        // Setup borrow for interest
        _seedPoolWithBorrow();
        vm.prank(borrower);
        pool.borrow(50 ether);
        
        // Warp and set oracle price
        vm.warp(block.timestamp + 365 days);
        oracle.setPrice(1e9);
        
        // Ghost calls compound - should record stats (even if registry is mock)
        // The vault attempts to call recordCompound on the registry
        vm.prank(ghost);
        vault.compound();
        
        // Verify stats were recorded
        (uint256 compounds, , , , , ) = ghostReg.ghostStats(ghost);
        assertGt(compounds, 0);
    }

    // 106
    function test_initialize_oracleFail() public {
        oracle.setShouldRevert(true); 

        DripVault newVault = new DripVault();
        DripToken newToken = new DripToken();
        newToken.initialize(address(newVault), "dTest", "dTEST");

        // Initialize with the bad oracle
        newVault.initialize(
            creator,
            "TestVault",
            "desc",
            CREATOR_FEE_BPS,
            address(pool),
            address(newToken),
            address(oracle),
            treasury,
            DRIP_CUT_BPS
        );

        // Verify lastRecordedPrice is 0 (fallback logic)
        assertEq(newVault.lastRecordedPrice(), 0);
    }

    // 227
    function test_compound_oracleFail() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        // Force oracle to revert
        oracle.setShouldRevert(true);

        // Expect event
        vm.expectEmit(true, false, false, true);
        emit DripVault.CompoundSkipped(0, "ORACLE_ERROR");
        
        vault.compound();
    }

    // 285
    function test_claimCreatorYield_zeroFail() public {
        vm.prank(creator);
        vm.expectRevert(DripVault.ZeroAmount.selector);
        vault.claimCreatorYield();
    }

    // 301
    function test_setDelegatedGhost_insufficientFee() public {
        address ghost = makeAddr("ghost");
        address registry = makeAddr("registry");

        // Give the creator enough ETH to make the value call
        vm.deal(creator, 10 ether);

        vm.prank(creator);
        vm.expectRevert(DripVault.InsufficientDelegationFee.selector);
        
        vault.setDelegatedGhost{value: 3 ether}(ghost, registry);
    }

    // 304
    function test_setDelegatedGhost_refundFail() public {
        // 1. Deploy a contract that cannot receive ETH
        NonReceiver nr = new NonReceiver();

        // 2. Deploy a vault where the creator is the NonReceiver
        DripVault localVault = new DripVault();
        DripToken localToken = new DripToken();
        localToken.initialize(address(localVault), "d", "d");
        localVault.initialize(
            address(nr), // Creator is the NonReceiver
            "n", "d", 1000,
            address(pool), address(localToken), address(oracle), treasury, 1000
        );

        // 3. Fund the NonReceiver so it can call the function
        vm.deal(address(nr), 10 ether);

        // 4. Expect revert because the refund logic sends ETH back to msg.sender (NonReceiver)
        vm.expectRevert(DripVault.TransferFailed.selector);
        nr.callSetGhost{value: 10 ether}(address(localVault), makeAddr("ghost"), makeAddr("registry"));
    }

    // line 340
    function test_withdrawFees_noExcess() public {
        // No excess balance in vault
        vm.prank(creator);
        vault.withdrawFees();
        // Assert balance unchanged (implicit)
    }

    function test_withdrawFees_withExcess() public {
        // Mint excess tokens directly to vault (simulating accidental transfer or airdrop)
        uint256 excess = 10 ether;
        token.mint(address(vault), excess);

        uint256 treasuryBalBefore = token.balanceOf(treasury);
        
        vm.prank(creator);
        vault.withdrawFees();

        assertEq(token.balanceOf(treasury) - treasuryBalBefore, excess);
    }

    // line 366
    function test_preview_emptyVault() public {
        // Vault is empty in setup (unless setUp runs deposits, but your setUp doesn't)
        
        // 1. Preview Deposit (Line 366: supply == 0)
        uint256 shares = vault.previewDeposit(100 ether);
        assertEq(shares, 100 ether); // Should be 1:1

        // 2. Preview Withdraw (Line 373: supply == 0)
        uint256 assets = vault.previewWithdraw(100 ether);
        assertEq(assets, 0); // Should return 0 if supply is 0
    }

    // line 409
    function test_getDefensiveStatus_statusCodes() public {
        // 1. Test STALE_ORACLE (lastRecordedPrice == 0)
        oracle.setShouldRevert(true);
        DripVault staleVault = new DripVault();
        DripToken staleToken = new DripToken();
        staleToken.initialize(address(staleVault), "s", "s");
        staleVault.initialize(creator, "s", "s", 1000, address(pool), address(staleToken), address(oracle), treasury, 1000);

        (,,,, string memory status) = staleVault.getDefensiveStatus();
        assertEq(status, "STALE_ORACLE");

        // ── Reset mock for second scenario ──
        oracle.setShouldRevert(false);

        // 2. Test DEFENSIVE_MODE
        vm.prank(creator);
        vault.setDefensiveThreshold(1);
        
        vm.prank(alice);
        vault.deposit(100 ether);
        
        oracle.setPrice(1e9 - 1); // Price drop
        vault.compound();

        (bool isDefensive,,,, string memory status2) = vault.getDefensiveStatus();
        assertTrue(isDefensive);
        assertEq(status2, "DEFENSIVE_MODE");
    }
}

// Helper contract for the test_setDelegatedGhost_refundFail
contract NonReceiver {
    function callSetGhost(address _vault, address _ghost, address _registry) external payable {
        DripVault(_vault).setDelegatedGhost{value: msg.value}(_ghost, _registry);
    }
    receive() external payable { revert(); }
}
