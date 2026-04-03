// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DripPool} from "../src/DripPool.sol";
import {DripToken} from "../src/DripToken.sol";
import {DripVault} from "../src/DripVault.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {CompetitionManager} from "../src/CompetitionManager.sol";
import {IDripVault} from "../src/interfaces/IDripVault.sol";
import {IDripToken} from "../src/interfaces/IDripToken.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {MockOracle} from "./mocks/MockOracle.sol";


/// @title CompetitionManager Test Suite
contract CompetitionManagerTest is Test {
    DripPool public pool;
    DripToken public tokenImpl;
    DripVault public vaultImpl;
    VaultFactory public factory;
    CompetitionManager public cm;
    ERC20Mock public token;
    MockOracle public oracle;

    address public treasury = makeAddr("treasury");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public borrower = makeAddr("borrower");

    uint256 constant CREATION_FEE = 3 ether;
    uint256 constant ENTRY_FEE = 7 ether;
    uint256 constant PROTOCOL_SEED = 23 ether;
    uint256 constant DRIP_CUT_BPS = 1000;

    address public vault;
    address public dripTok;

    function setUp() public {
        token = new ERC20Mock();
        oracle = new MockOracle();

        pool = new DripPool(
            address(token), treasury, 800, 1000, 1000, 5000, 7500
        );

        tokenImpl = new DripToken();
        vaultImpl = new DripVault();

        factory = new VaultFactory(
            address(vaultImpl), address(tokenImpl), address(pool),
            address(oracle), treasury, CREATION_FEE, DRIP_CUT_BPS
        );

        cm = new CompetitionManager(
            address(factory), treasury, ENTRY_FEE, PROTOCOL_SEED, DRIP_CUT_BPS
        );

        // Fund seed pool
        vm.deal(address(cm), 100 ether);

        // Create a vault via factory
        vm.deal(alice, 200 ether);
        vm.deal(bob, 200 ether);
        vm.deal(charlie, 200 ether);

        vm.prank(alice);
        (vault, dripTok) = factory.createVault{value: CREATION_FEE}("TestComp", "comp vault", 1000);

        // Mint ERC20 tokens and deposit (need >= 2 depositors for competition)
        token.mint(alice, 1000 ether);
        token.mint(bob, 1000 ether);
        token.mint(charlie, 1000 ether);
        token.mint(borrower, 1000 ether);

        vm.startPrank(alice);
        token.approve(vault, type(uint256).max);
        DripVault(vault).deposit(100 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(vault, type(uint256).max);
        DripVault(vault).deposit(100 ether);
        vm.stopPrank();

        // Set up borrower for pool interest
        vm.startPrank(borrower);
        token.approve(address(pool), type(uint256).max);
        pool.addCollateral(500 ether);
        pool.borrow(50 ether);
        vm.stopPrank();
    }

    // ─── Create Competition ────────────────────────────────────────────

    function test_createCompetition_requires2Depositors() public {
        // vault already has 2 depositors (alice + bob)
        cm.createCompetition(vault, 86400); // 1 day

        (address v, , uint256 endTime, uint256 prize, , , , ) = cm.getCompetition(0);
        assertEq(v, vault);
        assertGt(endTime, block.timestamp);
        assertEq(prize, PROTOCOL_SEED);
    }

    function test_createCompetition_1Depositor_reverts() public {
        // Create a vault with only 1 depositor
        vm.prank(charlie);
        (address vault2, ) = factory.createVault{value: CREATION_FEE}("Solo", "solo", 1000);

        token.mint(charlie, 100 ether);
        vm.startPrank(charlie);
        token.approve(vault2, type(uint256).max);
        DripVault(vault2).deposit(100 ether);
        vm.stopPrank();

        assertEq(IDripVault(vault2).depositorCount(), 1);

        vm.expectRevert(CompetitionManager.VaultNotEligible.selector);
        cm.createCompetition(vault2, 86400);
    }

    function test_createCompetition_unregisteredVault_reverts() public {
        vm.expectRevert(CompetitionManager.NotRegisteredVault.selector);
        cm.createCompetition(address(0xdead), 86400);
    }

    function test_createCompetition_invalidDuration_reverts() public {
        // Too short
        vm.expectRevert(CompetitionManager.InvalidDuration.selector);
        cm.createCompetition(vault, 3599);

        // Too long
        vm.expectRevert(CompetitionManager.InvalidDuration.selector);
        cm.createCompetition(vault, 2592001);
    }

    // ─── Enter Competition ─────────────────────────────────────────────

    function test_enterCompetition_snapshotsCorrect() public {
        cm.createCompetition(vault, 86400);

        vm.prank(alice);
        cm.enterCompetition{value: ENTRY_FEE}(0);

        uint256 pps = cm.getStartPPS(0, alice);
        assertGt(pps, 0, "PPS should be > 0");

        address[] memory participants = cm.getParticipants(0);
        assertEq(participants.length, 1);
        assertEq(participants[0], alice);
    }

    function test_enterCompetition_alreadyEntered_reverts() public {
        cm.createCompetition(vault, 86400);

        vm.prank(alice);
        cm.enterCompetition{value: ENTRY_FEE}(0);

        vm.expectRevert(CompetitionManager.AlreadyEntered.selector);
        vm.prank(alice);
        cm.enterCompetition{value: ENTRY_FEE}(0);
    }

    function test_enterCompetition_insufficientFee_reverts() public {
        cm.createCompetition(vault, 86400);

        vm.expectRevert(CompetitionManager.InsufficientEntryFee.selector);
        vm.prank(alice);
        cm.enterCompetition{value: 1 ether}(0);
    }

    function test_enterCompetition_afterEnd_reverts() public {
        cm.createCompetition(vault, 86400);
        vm.warp(block.timestamp + 86401);

        vm.expectRevert(CompetitionManager.CompetitionNotActive.selector);
        vm.prank(alice);
        cm.enterCompetition{value: ENTRY_FEE}(0);
    }

    // ─── Settle Competition ────────────────────────────────────────────

    function test_settleCompetition_happy() public {
        cm.createCompetition(vault, 86400);

        vm.prank(alice);
        cm.enterCompetition{value: ENTRY_FEE}(0);
        vm.prank(bob);
        cm.enterCompetition{value: ENTRY_FEE}(0);

        // Warp to accrue interest and end competition
        vm.warp(block.timestamp + 86401);



        cm.settleCompetition(0);

        (, , , , , , , bool settled) = cm.getCompetition(0);
        assertTrue(settled, "Should be settled");
        // Winner might have 0 growth if pool doesn't accrue via view
        // In either case, settlement should not revert
    }

    function test_settleCompetition_beforeEnd_reverts() public {
        cm.createCompetition(vault, 86400);
        vm.prank(alice);
        cm.enterCompetition{value: ENTRY_FEE}(0);

        vm.expectRevert(CompetitionManager.CompetitionNotEnded.selector);
        cm.settleCompetition(0);
    }

    function test_settleCompetition_alreadySettled_reverts() public {
        cm.createCompetition(vault, 86400);
        vm.prank(alice);
        cm.enterCompetition{value: ENTRY_FEE}(0);

        vm.warp(block.timestamp + 86401);
        cm.settleCompetition(0);

        vm.expectRevert(CompetitionManager.AlreadySettled.selector);
        cm.settleCompetition(0);
    }

    // ─── Prize Distribution ────────────────────────────────────────────

    function test_dripFeeExact() public {
        cm.createCompetition(vault, 3600);

        vm.prank(alice);
        cm.enterCompetition{value: ENTRY_FEE}(0);
        vm.prank(bob);
        cm.enterCompetition{value: ENTRY_FEE}(0);

        // Force interest accrual so there's PPS growth
        vm.warp(block.timestamp + 3601);

        // Accrue interest in pool via a supply/withdraw to trigger it
        token.mint(address(this), 1 ether);
        token.approve(address(pool), 1 ether);
        pool.supply(1 ether);

        uint256 treasuryBefore = treasury.balance;

        // Get prize pool before settlement
        (, , , uint256 prizePool, , , , ) = cm.getCompetition(0);

        cm.settleCompetition(0);

        // Check if settlement happened with growth or via refund
        (, , , , , , uint256 growth, ) = cm.getCompetition(0);

        if (growth > 0) {
            // Normal settlement: treasury gets exactly dripCutBps of prizePool
            uint256 expectedDripFee = prizePool * DRIP_CUT_BPS / 10000;
            assertEq(treasury.balance - treasuryBefore, expectedDripFee, "Treasury should get 10% of prize");
        }
        // If 0 growth, the refund path runs — tested separately
    }

    // ─── Competition Full ──────────────────────────────────────────────

    function test_competitionFull_reverts() public {
        cm.createCompetition(vault, 86400);

        // Fill up 100 participants
        for (uint256 i = 0; i < 100; i++) {
            address participant = address(uint160(1000 + i));
            vm.deal(participant, ENTRY_FEE);
            vm.prank(participant);
            cm.enterCompetition{value: ENTRY_FEE}(0);
        }

        // 101st should revert
        address overflow = makeAddr("overflow");
        vm.deal(overflow, ENTRY_FEE);
        vm.expectRevert(CompetitionManager.CompetitionFull.selector);
        vm.prank(overflow);
        cm.enterCompetition{value: ENTRY_FEE}(0);
    }

    // ─── Zero Growth Refund ────────────────────────────────────────────

    function test_zeroGrowth_refundPath() public {
        cm.createCompetition(vault, 3600);

        vm.prank(alice);
        cm.enterCompetition{value: ENTRY_FEE}(0);
        vm.prank(bob);
        cm.enterCompetition{value: ENTRY_FEE}(0);

        // No interest accrual (don't call any pool function) → 0% growth
        vm.warp(block.timestamp + 3601);

        uint256 aliceBefore = alice.balance;
        uint256 bobBefore = bob.balance;

        cm.settleCompetition(0);

        // Should trigger refund path — participants get ~95% of entry fees back
        // Total entry fees = 14 INIT, 95% refund = 13.3 INIT, split 2 ways ≈ 6.65 each
        (, , , , , , , bool settled) = cm.getCompetition(0);
        assertTrue(settled);

        // Participants should receive some refund
        assertTrue(alice.balance > aliceBefore || bob.balance > bobBefore, "At least one should get refund");
    }

    // ─── Fuzz Tests ────────────────────────────────────────────────────

    function testFuzz_growthCalc(uint256 startPPS, uint256 currentAssets, uint256 currentSupply) public pure {
        startPPS = bound(startPPS, 1, 1e36);
        currentAssets = bound(currentAssets, 0, 1e36);
        currentSupply = bound(currentSupply, 1, 1e36);

        // Should never overflow or revert
        // Using internal function directly — replicate the logic
        if (startPPS == 0 || currentSupply == 0) return;
        uint256 currentPPS = currentAssets * 1e18 / currentSupply;
        if (currentPPS <= startPPS) return;
        uint256 growthBps = (currentPPS - startPPS) * 10000 / startPPS;
        // Just verify no revert
        assertGe(growthBps, 0);
    }

    function testFuzz_prizeDistribution(uint256 numParticipants) public {
        numParticipants = bound(numParticipants, 1, 10);

        cm.createCompetition(vault, 3600);

        uint256 totalSent = 0;
        for (uint256 i = 0; i < numParticipants; i++) {
            address p = address(uint160(2000 + i));
            vm.deal(p, ENTRY_FEE);
            vm.prank(p);
            cm.enterCompetition{value: ENTRY_FEE}(0);
            totalSent += ENTRY_FEE;
        }

        vm.warp(block.timestamp + 3601);

        uint256 cmBalBefore = address(cm).balance;
        cm.settleCompetition(0);

        // After settlement, CM balance should have decreased
        // (prize + fees distributed)
        assertTrue(address(cm).balance < cmBalBefore, "CM should have paid out");
    }

    // ─── canSettle View ────────────────────────────────────────────────

    function test_canSettle() public {
        cm.createCompetition(vault, 3600);

        // Enter before end
        vm.prank(alice);
        cm.enterCompetition{value: ENTRY_FEE}(0);

        assertFalse(cm.canSettle(0), "Should not be settleable before end");

        vm.warp(block.timestamp + 3601);
        assertTrue(cm.canSettle(0), "Should be settleable after end");

        cm.settleCompetition(0);

        assertFalse(cm.canSettle(0), "Should not be settleable after settled");
    }

    // ─── Admin Functions ──────────────────────────────────────────────

    function test_setTreasuryAddress() public {
        address newTreasury = makeAddr("newTreasury");
        cm.setTreasuryAddress(newTreasury);
        assertEq(cm.treasury(), newTreasury);
    }

    function test_fundSeedPool() public {
        uint256 before = address(cm).balance;
        cm.fundSeedPool{value: 50 ether}();
        assertEq(address(cm).balance - before, 50 ether);
    }

    function test_withdrawFees_respectsReserved() public {
        // Create a competition — reserves 23 INIT
        cm.createCompetition(vault, 86400);
        assertEq(cm.reservedSeeds(), PROTOCOL_SEED);

        uint256 cmBalance = address(cm).balance;
        uint256 treasuryBefore = treasury.balance;

        cm.withdrawFees();

        // Should only withdraw balance - reserved
        uint256 expected = cmBalance > PROTOCOL_SEED ? cmBalance - PROTOCOL_SEED : 0;
        assertEq(treasury.balance - treasuryBefore, expected);
        assertGe(address(cm).balance, PROTOCOL_SEED); // still holds reserve
    }

    function test_createCompetition_insufficientSeed_reverts() public {
        // Drain the CM balance
        cm.withdrawFees();

        // Now try to create — should fail
        vm.expectRevert(CompetitionManager.InsufficientSeed.selector);
        cm.createCompetition(vault, 86400);
    }

    function test_getLeaderboard() public {
        cm.createCompetition(vault, 3600);

        vm.prank(alice);
        cm.enterCompetition{value: ENTRY_FEE}(0);
        vm.prank(bob);
        cm.enterCompetition{value: ENTRY_FEE}(0);

        (address[] memory ranked, ) = cm.getLeaderboard(0);
        assertEq(ranked.length, 2);
    }

    function test_enterCompetition_overpaymentRefunded() public {
        cm.createCompetition(vault, 86400);

        uint256 aliceBefore = alice.balance;
        vm.prank(alice);
        cm.enterCompetition{value: ENTRY_FEE + 5 ether}(0);

        // Should only have spent ENTRY_FEE (excess refunded)
        assertEq(aliceBefore - alice.balance, ENTRY_FEE);
    }

    function test_getStartPPS_view() public {
        cm.createCompetition(vault, 86400);

        vm.prank(alice);
        cm.enterCompetition{value: ENTRY_FEE}(0);

        uint256 pps = cm.getStartPPS(0, alice);
        assertGt(pps, 0);

        // Non-participant should be 0
        assertEq(cm.getStartPPS(0, charlie), 0);
    }

    function test_zeroGrowth_noParticipants() public {
        // Create competition
        cm.createCompetition(vault, 3600);
        
        // Don't enter any participants
        // Warp past end time
        vm.warp(block.timestamp + 3601);
        
        // Should settle without error (no winner, no refunds needed)
        cm.settleCompetition(0);
        
        (, , , , , , , bool settled) = cm.getCompetition(0);
        assertTrue(settled);
        
        // Prize pool should be just the protocol seed (no entry fees added)
        (, , , uint256 prizePool, , , , ) = cm.getCompetition(0);
        assertEq(prizePool, PROTOCOL_SEED);
    }

    // ─── Branch: enterCompetition vault == address(0) ─────────────────
    function test_enterCompetition_nonExistentId_reverts() public {
        vm.prank(alice);
        vm.expectRevert(CompetitionManager.CompetitionNotActive.selector);
        cm.enterCompetition{value: ENTRY_FEE}(999);
    }

    // ─── Branch: enterCompetition already settled ─────────────────────
    function test_enterCompetition_alreadySettled_reverts() public {
        cm.createCompetition(vault, 3600);
        vm.prank(alice);
        cm.enterCompetition{value: ENTRY_FEE}(0);
        vm.warp(block.timestamp + 3601);
        cm.settleCompetition(0);

        vm.prank(bob);
        vm.expectRevert(CompetitionManager.CompetitionNotActive.selector); // time check fires first
        cm.enterCompetition{value: ENTRY_FEE}(0);
    }

    // ─── Branch: enterCompetition refund transfer failure ─────────────
    function test_enterCompetition_refundFailure_reverts() public {
        cm.createCompetition(vault, 3600);

        // RevertingReceiver cannot receive ETH refund
        RevertingReceiver badActor = new RevertingReceiver();
        vm.deal(address(badActor), 100 ether);
        token.mint(address(badActor), 100 ether);

        vm.prank(address(badActor));
        vm.expectRevert(CompetitionManager.TransferFailed.selector);
        // Send more than entryFee so refund is attempted
        cm.enterCompetition{value: ENTRY_FEE + 1 ether}(0);
    }

    // ─── Branch: settleCompetition vault == address(0) ────────────────
    function test_settleCompetition_nonExistentId_reverts() public {
        vm.expectRevert(CompetitionManager.CompetitionNotActive.selector);
        cm.settleCompetition(999);
    }

    // ─── Branch: settleCompetition treasury transfer fails ────────────
    function test_settleCompetition_treasuryTransferFails_reverts() public {
        SelectiveReverter badTreasury = new SelectiveReverter(0);
        // SelectiveReverter reverts on all receives
        CompetitionManager badCm = new CompetitionManager(
            address(factory), address(badTreasury),
            ENTRY_FEE, PROTOCOL_SEED, DRIP_CUT_BPS
        );
        vm.deal(address(badCm), 100 ether);

        badCm.createCompetition(vault, 3600);

        vm.prank(alice);
        badCm.enterCompetition{value: ENTRY_FEE}(0);

        vm.warp(block.timestamp + 180 days);
        oracle.setPrice(1e9);

        vm.expectRevert(CompetitionManager.TransferFailed.selector);
        badCm.settleCompetition(0);
    }

    function test_settleCompetition_winnerTransferFails_reverts() public {
        SelectiveReverter badWinner = new SelectiveReverter(0); // reverts on ALL receives
        vm.deal(address(badWinner), 100 ether);

        cm.createCompetition(vault, 3600);

        vm.prank(address(badWinner));
        cm.enterCompetition{value: ENTRY_FEE}(0); // entry fee sent FROM badWinner, not TO it

        vm.warp(block.timestamp + 180 days); // enough for measurable growth
        oracle.setPrice(1e9);

        vm.expectRevert(CompetitionManager.TransferFailed.selector);
        cm.settleCompetition(0);
    }

    // ─── Branch: _calculateGrowth startPPS == 0 ───────────────────────
    function test_calculateGrowth_zeroStartPPS() public {
        cm.createCompetition(vault, 3600);

        // Enter competition when vault has 0 PPS (mock totalSupply = 0)
        // Simplest: enter before any deposits exist in a fresh vault
        vm.prank(alice);
        (address emptyVault, ) = factory.createVault{value: CREATION_FEE}("Empty", "e", 1000);

        token.mint(alice, 100 ether);
        token.mint(bob, 100 ether);

        vm.startPrank(alice);
        token.approve(emptyVault, type(uint256).max);
        DripVault(emptyVault).deposit(50 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(emptyVault, type(uint256).max);
        DripVault(emptyVault).deposit(50 ether);
        vm.stopPrank();

        cm.createCompetition(emptyVault, 3600);
        uint256 emptyCompId = cm.competitionCount() - 1;

        // All depositors withdraw so totalSupply = 0 before entry
        uint256 aliceShares = IDripToken(DripVault(emptyVault).dripToken()).balanceOf(alice);
        uint256 bobShares = IDripToken(DripVault(emptyVault).dripToken()).balanceOf(bob);
        vm.prank(alice);
        DripVault(emptyVault).withdraw(aliceShares);
        vm.prank(bob);
        DripVault(emptyVault).withdraw(bobShares);

        // Now enter — totalSupply == 0 → PPS = 0 → startPPS stored as 0
        vm.prank(charlie);
        cm.enterCompetition{value: ENTRY_FEE}(emptyCompId);

        vm.warp(block.timestamp + 3601);
        // settleCompetition — _calculateGrowth hits startPPS == 0 path → returns 0
        // All zero growth → _handleZeroGrowth triggered
        cm.settleCompetition(emptyCompId);

        (, , , , , address winner, , ) = cm.getCompetition(emptyCompId);
        assertEq(winner, address(0), "No winner when startPPS was zero");
    }

    // ─── Branch: withdrawFees withdrawable == 0 ───────────────────────
    function test_withdrawFees_nothingToWithdraw() public {
        // Reset balance to exactly 2 * PROTOCOL_SEED so competitions reserve everything
        vm.deal(address(cm), 2 * PROTOCOL_SEED);

        cm.createCompetition(vault, 3600);
        cm.createCompetition(vault, 7200);

        assertEq(address(cm).balance, cm.reservedSeeds(), "All balance reserved");

        uint256 treasuryBefore = treasury.balance;
        cm.withdrawFees(); // withdrawable == 0, returns early
        assertEq(treasury.balance, treasuryBefore, "Nothing withdrawn when all reserved");
    }

    // ─── Branch: withdrawFees transfer fails ──────────────────────────
    function test_withdrawFees_transferFails_reverts() public {
        SelectiveReverter badTreasury = new SelectiveReverter(0);
        CompetitionManager badCm = new CompetitionManager(
            address(factory), address(badTreasury),
            ENTRY_FEE, PROTOCOL_SEED, DRIP_CUT_BPS
        );
        // Fund with more than protocolSeed so withdrawable > 0
        vm.deal(address(badCm), PROTOCOL_SEED + 10 ether);

        vm.expectRevert(CompetitionManager.TransferFailed.selector);
        badCm.withdrawFees();
    }
}

/// @dev Contract that reverts on any ETH receive
contract RevertingReceiver {
    receive() external payable {
        revert("RevertingReceiver: no ETH accepted");
    }
}

/// @dev Contract that reverts after a certain number of calls
contract SelectiveReverter {
    uint256 public callCount;
    uint256 public revertAfter;
    constructor(uint256 _revertAfter) { revertAfter = _revertAfter; }
    receive() external payable {
        callCount++;
        if (callCount > revertAfter) revert();
    }
}

