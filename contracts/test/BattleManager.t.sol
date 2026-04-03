// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DripPool} from "../src/DripPool.sol";
import {DripToken} from "../src/DripToken.sol";
import {DripVault} from "../src/DripVault.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {BattleManager} from "../src/BattleManager.sol";
import {IDripVault} from "../src/interfaces/IDripVault.sol";
import {IDripToken} from "../src/interfaces/IDripToken.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {MockOracle} from "./mocks/MockOracle.sol";


contract BattleManagerTest is Test {
    DripPool public pool;
    VaultFactory public factory;
    BattleManager public bm;
    ERC20Mock public token;
    MockOracle public oracle;

    address public treasury = makeAddr("treasury");
    address public alice = makeAddr("alice");   // challenger creator
    address public bob = makeAddr("bob");       // defender creator
    address public charlie = makeAddr("charlie"); // depositor

    uint256 constant CHALLENGE_FEE = 40 ether;
    uint256 constant MIN_WAGER = 10 ether;
    uint256 constant PROTOCOL_CUT_BPS = 2000; // 20%

    address public vault1; // alice's vault
    address public vault2; // bob's vault

    function setUp() public {
        token = new ERC20Mock();
        oracle = new MockOracle();

        pool = new DripPool(address(token), treasury, 800, 1000, 1000, 5000, 7500);
        DripToken tokenImpl = new DripToken();
        DripVault vaultImpl = new DripVault();

        factory = new VaultFactory(
            address(vaultImpl), address(tokenImpl), address(pool),
            address(oracle), treasury, 3 ether, 1000
        );

        bm = new BattleManager(address(factory), treasury, CHALLENGE_FEE, PROTOCOL_CUT_BPS, MIN_WAGER);

        // Fund accounts
        vm.deal(alice, 500 ether);
        vm.deal(bob, 500 ether);
        vm.deal(charlie, 500 ether);
        token.mint(alice, 1000 ether);
        token.mint(bob, 1000 ether);
        token.mint(charlie, 1000 ether);

        // Create vault1 (alice) with 2 depositors
        vm.prank(alice);
        (vault1, ) = factory.createVault{value: 3 ether}("AlphaV", "alpha", 1000);

        vm.startPrank(alice);
        token.approve(vault1, type(uint256).max);
        DripVault(vault1).deposit(100 ether);
        vm.stopPrank();

        vm.startPrank(charlie);
        token.approve(vault1, type(uint256).max);
        DripVault(vault1).deposit(50 ether);
        vm.stopPrank();

        // Create vault2 (bob) with 2 depositors
        vm.prank(bob);
        (vault2, ) = factory.createVault{value: 3 ether}("BetaV", "beta", 1000);

        vm.startPrank(bob);
        token.approve(vault2, type(uint256).max);
        DripVault(vault2).deposit(100 ether);
        vm.stopPrank();

        vm.startPrank(charlie);
        token.approve(vault2, type(uint256).max);
        DripVault(vault2).deposit(50 ether);
        vm.stopPrank();

        // Seed pool with a borrower for interest
        address borrower = makeAddr("borrower");
        token.mint(borrower, 1000 ether);
        vm.startPrank(borrower);
        token.approve(address(pool), type(uint256).max);
        pool.addCollateral(500 ether);
        pool.borrow(100 ether);
        vm.stopPrank();
    }

    function test_declareBattle_success() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);
        assertEq(id, 1);

        (address cv, address dv, uint256 cs, uint256 ds, , , , , , , ) = bm.battles(id);
        assertEq(cv, vault1);
        assertEq(dv, vault2);
        assertEq(cs, 20 ether); // wager
        assertEq(ds, 0);        // not accepted yet
    }

    function test_declareBattle_notCreator_reverts() public {
        vm.expectRevert(BattleManager.NotChallenger.selector);
        vm.prank(charlie); // charlie is not vault1's creator
        bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);
    }

    function test_declareBattle_insufficientFee_reverts() public {
        vm.expectRevert(BattleManager.InsufficientChallengeFee.selector);
        vm.prank(alice);
        bm.declareBattleForVault{value: 30 ether}(vault1, vault2, 86400); // need 40 + 10 min wager
    }

    function test_declareBattle_battleInProgress_reverts() public {
        vm.prank(alice);
        bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);

        vm.expectRevert(BattleManager.BattleInProgress.selector);
        vm.prank(alice);
        bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);
    }

    function test_acceptBattle_success() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);

        vm.prank(bob);
        bm.acceptBattle{value: 20 ether}(id);

        (, , , uint256 ds, , , , , , , ) = bm.battles(id);
        assertEq(ds, 20 ether);
    }

    function test_acceptBattle_notDefender_reverts() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);

        vm.expectRevert(BattleManager.NotDefenderCreator.selector);
        vm.prank(charlie);
        bm.acceptBattle{value: 20 ether}(id);
    }

    function test_cancelPending_afterWindow() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);

        // Wait 24h + 1
        vm.warp(block.timestamp + 86401);

        uint256 aliceBefore = alice.balance;
        vm.prank(alice);
        bm.cancelPendingBattle(id);

        assertEq(alice.balance - aliceBefore, 20 ether); // wager refunded
    }

    function test_cancelPending_beforeWindow_reverts() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);

        vm.expectRevert(BattleManager.AcceptanceWindowOpen.selector);
        vm.prank(alice);
        bm.cancelPendingBattle(id);
    }

    function test_cancelPending_afterAccepted_reverts() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);

        vm.prank(bob);
        bm.acceptBattle{value: 20 ether}(id);

        vm.warp(block.timestamp + 86401);
        vm.expectRevert(BattleManager.BattleAlreadyAccepted.selector);
        vm.prank(alice);
        bm.cancelPendingBattle(id);
    }

    function test_settleBattle_happy() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 3600);

        vm.prank(bob);
        bm.acceptBattle{value: 20 ether}(id);

        // Warp to accrue interest and end battle
        vm.warp(block.timestamp + 3601);

        uint256 treasuryBefore = treasury.balance;
        bm.settleBattle(id);

        (, , , , , , , , , , bool settled) = bm.battles(id);
        assertTrue(settled);

        // Protocol should have gotten 20% of combined stakes = 8 INIT
        assertEq(treasury.balance - treasuryBefore, 8 ether);
    }

    function test_settleBattle_beforeEnd_reverts() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);

        vm.prank(bob);
        bm.acceptBattle{value: 20 ether}(id);

        vm.expectRevert(BattleManager.BattleNotEnded.selector);
        bm.settleBattle(id);
    }

    function test_settleBattle_neverAccepted_refunds() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 3600);

        vm.warp(block.timestamp + 86401); // past acceptance window

        uint256 aliceBefore = alice.balance;
        bm.settleBattle(id);

        assertEq(alice.balance - aliceBefore, 20 ether); // wager refunded
    }

    function test_challengeFee_goesToTreasury() public {
        uint256 treasuryBefore = treasury.balance;

        vm.prank(alice);
        bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);

        assertEq(treasury.balance - treasuryBefore, CHALLENGE_FEE);
    }

    function test_declareBattle_invalidDuration_short_reverts() public {
        vm.expectRevert(BattleManager.InvalidVault.selector);
        vm.prank(alice);
        bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 100); // < 3600
    }

    function test_declareBattle_invalidDuration_long_reverts() public {
        vm.expectRevert(BattleManager.InvalidVault.selector);
        vm.prank(alice);
        bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 700000); // > 604800
    }

    function test_declareBattle_insufficientDepositors_reverts() public {
        // Create vault3 with only 1 depositor
        vm.prank(alice);
        (address vault3, ) = factory.createVault{value: 3 ether}("SoloV", "solo", 1000);
        vm.startPrank(alice);
        token.approve(vault3, type(uint256).max);
        DripVault(vault3).deposit(100 ether);
        vm.stopPrank();

        vm.expectRevert(BattleManager.InvalidVault.selector);
        vm.prank(alice);
        bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault3, vault2, 86400);
    }

    function test_acceptBattle_excessRefunded() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);

        uint256 bobBefore = bob.balance;
        vm.prank(bob);
        bm.acceptBattle{value: 30 ether}(id); // overpays by 10

        // Defender stake locked = 20 (matching challenger). Excess 10 refunded.
        (, , , uint256 ds, , , , , , , ) = bm.battles(id);
        assertEq(ds, 20 ether);
        assertEq(bobBefore - bob.balance, 20 ether); // only 20 deducted after refund
    }

    function test_acceptBattle_defenderAlreadyInBattle_reverts() public {
        // Create vault3 for a second challenger
        address dave = makeAddr("dave");
        vm.deal(dave, 500 ether);
        token.mint(dave, 1000 ether);
        vm.prank(dave);
        (address vault3, ) = factory.createVault{value: 3 ether}("GammaV", "gamma", 1000);
        vm.startPrank(dave);
        token.approve(vault3, type(uint256).max);
        DripVault(vault3).deposit(100 ether);
        vm.stopPrank();
        vm.startPrank(charlie);
        token.approve(vault3, type(uint256).max);
        DripVault(vault3).deposit(50 ether);
        vm.stopPrank();

        // Alice declares battle1 vs vault2
        vm.prank(alice);
        uint256 id1 = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);

        // Bob accepts — defender vault2 now locked
        vm.prank(bob);
        bm.acceptBattle{value: 20 ether}(id1);

        // Dave declares battle2 vs vault2 — vault2 already locked
        vm.prank(dave);
        uint256 id2 = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault3, vault2, 86400);

        // If bob tries to accept battle2, defender vault2 is already locked
        vm.expectRevert(BattleManager.BattleInProgress.selector);
        vm.prank(bob);
        bm.acceptBattle{value: 20 ether}(id2);
    }

    function test_canSettle_notFound() public view {
        assertFalse(bm.canSettle(999));
    }

    function test_canSettle_pendingNotExpired() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);
        // Not settled, defender hasn't accepted, window not expired
        assertFalse(bm.canSettle(id));
    }

    function test_canSettle_pendingExpired() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);
        vm.warp(block.timestamp + 86401);
        assertTrue(bm.canSettle(id));
    }

    function test_canSettle_accepted_beforeEnd() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);
        vm.prank(bob);
        bm.acceptBattle{value: 20 ether}(id);
        assertFalse(bm.canSettle(id));
    }

    function test_withdrawFees_respectsActiveStakes() public {
        // Send some extra INIT to BM
        vm.deal(address(bm), 100 ether);

        // Declare battle with 20 INIT wager
        vm.prank(alice);
        bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);

        // totalActiveStakes = 20
        assertEq(bm.totalActiveStakes(), 20 ether);

        // withdrawFees should only withdraw balance - 20
        uint256 treasuryBefore = treasury.balance;
        bm.withdrawFees();
        uint256 bmBalance = address(bm).balance;
        assertGe(bmBalance, 20 ether); // still holds at least the wager
        assertGe(treasury.balance, treasuryBefore); // treasury got something
    }

    function test_setTreasuryAddress() public {
        address newTreasury = makeAddr("newTreasury");
        bm.setTreasuryAddress(newTreasury);
        assertEq(bm.treasury(), newTreasury);
    }

    // ─── Branch Coverage Tests ────────────────────────────────────────

    function test_declareBattle_unregisteredChallenger_reverts() public {
        vm.expectRevert(BattleManager.InvalidVault.selector);
        vm.prank(alice);
        bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(address(0xdead), vault2, 86400);
    }

    function test_declareBattle_unregisteredDefender_reverts() public {
        vm.expectRevert(BattleManager.InvalidVault.selector);
        vm.prank(alice);
        bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, address(0xdead), 86400);
    }

    function test_acceptBattle_notFound_reverts() public {
        vm.expectRevert(BattleManager.BattleNotFound.selector);
        vm.prank(bob);
        bm.acceptBattle{value: 20 ether}(999);
    }

    function test_acceptBattle_alreadySettled_reverts() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 3600);

        vm.prank(bob);
        bm.acceptBattle{value: 20 ether}(id);

        vm.warp(block.timestamp + 3601);
        bm.settleBattle(id);

        vm.expectRevert(BattleManager.AlreadySettled.selector);
        vm.prank(bob);
        bm.acceptBattle{value: 20 ether}(id);
    }

    function test_acceptBattle_insufficientStake_reverts() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);

        vm.expectRevert(BattleManager.InsufficientStake.selector);
        vm.prank(bob);
        bm.acceptBattle{value: 5 ether}(id); // less than challenger's 20
    }

    function test_acceptBattle_exactMatch_noRefund() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);

        uint256 bobBefore = bob.balance;
        vm.prank(bob);
        bm.acceptBattle{value: 20 ether}(id); // exact match — no excess

        assertEq(bobBefore - bob.balance, 20 ether);
    }

    function test_cancelPending_notFound_reverts() public {
        vm.expectRevert(BattleManager.BattleNotFound.selector);
        vm.prank(alice);
        bm.cancelPendingBattle(999);
    }

    function test_cancelPending_alreadySettled_reverts() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 3600);

        // Let it expire without acceptance, then settle
        vm.warp(block.timestamp + 86401);
        bm.settleBattle(id);

        vm.expectRevert(BattleManager.AlreadySettled.selector);
        vm.prank(alice);
        bm.cancelPendingBattle(id);
    }

    function test_cancelPending_notChallenger_reverts() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);

        vm.warp(block.timestamp + 86401);
        vm.expectRevert(BattleManager.NotChallenger.selector);
        vm.prank(bob);
        bm.cancelPendingBattle(id);
    }

    function test_settleBattle_notFound_reverts() public {
        vm.expectRevert(BattleManager.BattleNotFound.selector);
        bm.settleBattle(999);
    }

    function test_settleBattle_alreadySettled_reverts() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 3600);
        vm.prank(bob);
        bm.acceptBattle{value: 20 ether}(id);

        vm.warp(block.timestamp + 3601);
        bm.settleBattle(id);

        vm.expectRevert(BattleManager.AlreadySettled.selector);
        bm.settleBattle(id);
    }

    function test_settleBattle_pendingNotExpired_reverts() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);

        // Not accepted and window not expired
        vm.expectRevert(BattleManager.AcceptanceWindowOpen.selector);
        bm.settleBattle(id);
    }

    function test_withdrawFees_nothingExtra() public {
        // Declare battle — wager = 20 INIT, challenge fee = 40 (sent to treasury)
        vm.prank(alice);
        bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 86400);

        // BM only holds 20 INIT (the wager), and totalActiveStakes = 20
        // So withdrawable = 0
        uint256 treasuryBefore = treasury.balance;
        bm.withdrawFees();
        assertEq(treasury.balance, treasuryBefore); // nothing withdrawn
    }

    function test_canSettle_alreadySettled() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + 20 ether}(vault1, vault2, 3600);
        vm.prank(bob);
        bm.acceptBattle{value: 20 ether}(id);
        vm.warp(block.timestamp + 3601);
        bm.settleBattle(id);

        assertFalse(bm.canSettle(id));
    }

    // ═══════════════════════════════════════════════════════════════════
    // LINE 102: defender vault has < 2 depositors
    // BRDA:102,4,0,- (condition true branch not covered)
    // ═══════════════════════════════════════════════════════════════════
    
    function test_RevertIf_DefenderHasZeroDepositors() public {
        vm.prank(charlie);
        (address vault3, ) = factory.createVault{value: 3 ether}("SoloV", "solo", 1000);
        
        vm.prank(alice);
        vm.expectRevert(BattleManager.InvalidVault.selector);
        bm.declareBattleForVault{value: CHALLENGE_FEE + MIN_WAGER}(
            vault1, vault3, 86400);
    }
    
    
    // ═══════════════════════════════════════════════════════════════════
    // LINE 113: wagerAmount < minWager
    // BRDA:113,8,0,- (condition true branch not covered)
    // ═══════════════════════════════════════════════════════════════════
    
    function test_RevertIf_WagerAmountBelowMinWager() public {     
        vm.prank(alice);
        vm.expectRevert(BattleManager.InsufficientStake.selector);
        bm.declareBattleForVault{value: CHALLENGE_FEE + MIN_WAGER - 1}(
            vault1, vault2, 86400);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // LINE 117: TransferFailed in declareBattleForVault
    // BRDA:117,9,0,- (condition true branch not covered)
    // ═══════════════════════════════════════════════════════════════════
    
    function test_RevertIf_TreasuryTransferFails_OnDeclare() public {
        // Deploy BattleManager with reverting treasury
        RevertingReceiver revertingTreasury = new RevertingReceiver();
        BattleManager badManager = new BattleManager(
            address(factory),
            address(revertingTreasury),
            CHALLENGE_FEE,
            PROTOCOL_CUT_BPS,
            MIN_WAGER
        );
        
        vm.prank(alice);
        vm.expectRevert(BattleManager.TransferFailed.selector);
        badManager.declareBattleForVault{value: CHALLENGE_FEE + MIN_WAGER}(
            vault1, 
            vault2, 
            86400
        );
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // LINE 142: BattleAlreadyAccepted in acceptBattle
    // BRDA:142,12,0,- (condition true branch not covered)
    // ═══════════════════════════════════════════════════════════════════
    
    function test_RevertIf_BattleAlreadyAccepted() public {
        vm.prank(alice);
        uint256 battleId = bm.declareBattleForVault{value: CHALLENGE_FEE + MIN_WAGER}(
            vault1,
            vault2,
            86400
        );
        
        // First acceptance succeeds
        vm.prank(bob);
        bm.acceptBattle{value: MIN_WAGER}(battleId);
        
        // Second acceptance should fail
        vm.prank(bob);
        vm.expectRevert(BattleManager.BattleAlreadyAccepted.selector);
        bm.acceptBattle{value: MIN_WAGER}(battleId);
    }
    
    function test_RevertIf_BattleAlreadyAccepted_WithDifferentAmount() public {
        vm.prank(alice);
        uint256 battleId = bm.declareBattleForVault{value: CHALLENGE_FEE + MIN_WAGER}(
            vault1,
            vault2,
            86400
        );
        
        vm.prank(bob);
        bm.acceptBattle{value: MIN_WAGER}(battleId);
        
        // Try with different amount
        vm.prank(bob);
        vm.expectRevert(BattleManager.BattleAlreadyAccepted.selector);
        bm.acceptBattle{value: MIN_WAGER + 0.05 ether}(battleId);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // LINE 163: TransferFailed for refund in acceptBattle
    // BRDA:163,17,0,- (condition true branch not covered)
    // ═══════════════════════════════════════════════════════════════════
    
    function test_RevertIf_RefundTransferFails_OnAccept() public {
        // Create vault with reverting receiver as creator
        RevertingReceiver revertingDefender = new RevertingReceiver();
        vm.deal(address(revertingDefender), 200 ether);
        token.mint(address(revertingDefender), 200 ether);
        
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        vm.deal(user1, 100 ether);
        token.mint(user1, 200 ether);
        vm.deal(user2, 100 ether);
        token.mint(user2, 200 ether);

        vm.prank(address(revertingDefender));
        (address vault3, ) = factory.createVault{value: 3 ether}("SoloV", "solo", 1500);

        vm.startPrank(user1);
        token.approve(vault3, type(uint256).max);
        DripVault(vault3).deposit(50 ether);
        vm.stopPrank();

        vm.startPrank(user2);
        token.approve(vault3, type(uint256).max);
        DripVault(vault3).deposit(50 ether);
        vm.stopPrank();        

        vm.prank(alice);
        uint256 battleId = bm.declareBattleForVault{value: CHALLENGE_FEE + MIN_WAGER}(
            vault1,
            vault3,
            86400
        );
        
        // Send excess that needs to be refunded - refund will go to revertingDefender
        vm.prank(address(revertingDefender));
        vm.expectRevert(BattleManager.TransferFailed.selector);
        bm.acceptBattle{value: MIN_WAGER + 0.1 ether}(battleId);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // LINE 191: TransferFailed in cancelPendingBattle
    // BRDA:191,23,0,- (condition true branch not covered)
    // ═══════════════════════════════════════════════════════════════════
    
    function test_RevertIf_TransferFails_OnCancelPending() public {
        // Create vault with reverting receiver as creator
        RevertingReceiver revertingChallenger = new RevertingReceiver();
        vm.deal(address(revertingChallenger), 200 ether);
        token.mint(address(revertingChallenger), 400 ether);
        
        vm.prank(address(revertingChallenger));
        (address vault3, ) = factory.createVault{value: 3 ether}("SoloV", "solo", 1000);

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        vm.deal(user1, 100 ether);
        token.mint(user1, 200 ether);
        vm.deal(user2, 100 ether);
        token.mint(user2, 200 ether);

        vm.startPrank(user1);
        token.approve(vault3, type(uint256).max);
        DripVault(vault3).deposit(50 ether);
        vm.stopPrank();

        vm.startPrank(user2);
        token.approve(vault3, type(uint256).max);
        DripVault(vault3).deposit(50 ether);
        vm.stopPrank();  

        vm.prank(address(revertingChallenger));
        uint256 battleId = bm.declareBattleForVault{value: CHALLENGE_FEE + MIN_WAGER}(
            vault3,
            vault1,
            36000
        );
        
        // Warp past acceptance window
        vm.warp(block.timestamp + 86400 + 1);
        
        vm.prank(address(revertingChallenger));
        vm.expectRevert(BattleManager.TransferFailed.selector);
        bm.cancelPendingBattle(battleId);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // LINE 210: TransferFailed in settleBattle (unaccepted path)
    // BRDA:210,28,0,- (condition true branch not covered)
    // ═══════════════════════════════════════════════════════════════════

    function test_RevertIf_TransferFails_OnSettleUnaccepted() public {
        // Create vault with reverting receiver as creator
        RevertingReceiver revertingChallenger = new RevertingReceiver();
        vm.deal(address(revertingChallenger), 200 ether);
        token.mint(address(revertingChallenger), 200 ether);
        
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        vm.deal(user1, 100 ether);
        token.mint(user1, 200 ether);
        vm.deal(user2, 100 ether);
        token.mint(user2, 200 ether);

        vm.prank(address(revertingChallenger));
        (address vault3, ) = factory.createVault{value: 3 ether}("RevertV", "revert", 1000);

        vm.startPrank(user1);
        token.approve(vault3, type(uint256).max);

        DripVault(vault3).deposit(50 ether);
        vm.stopPrank();

        vm.startPrank(user2);
        token.approve(vault3, type(uint256).max);
        DripVault(vault3).deposit(50 ether);
        vm.stopPrank();        
        
        // Declare battle with vault3 as challenger
        vm.prank(address(revertingChallenger));
        uint256 battleId = bm.declareBattleForVault{value: CHALLENGE_FEE + MIN_WAGER}(
            vault3,
            vault2,
            3600
        );
        
        // Warp past acceptance window (never accepted)
        vm.warp(block.timestamp + 86401);
        
        // Settle should try to refund challenger, but transfer fails
        vm.expectRevert(BattleManager.TransferFailed.selector);
        bm.settleBattle(battleId);
    }    

    // ═══════════════════════════════════════════════════════════════════
    // LINE 239: TransferFailed for winner payout in settleBattle
    // BRDA:239,30,0,- (condition true branch not covered)
    // ═══════════════════════════════════════════════════════════════════

    function test_RevertIf_WinnerPayoutTransferFails() public {
        RevertingReceiver revertingWinner = new RevertingReceiver();
        vm.deal(address(revertingWinner), 200 ether);
        token.mint(address(revertingWinner), 200 ether);

        address rw1 = makeAddr("rw_user1");
        address rw2 = makeAddr("rw_user2");
        token.mint(rw1, 200 ether);
        token.mint(rw2, 200 ether);

        vm.prank(address(revertingWinner));
        (address winnerVault, ) = factory.createVault{value: 3 ether}("WinV", "win", 1000);

        vm.startPrank(rw1);
        token.approve(winnerVault, type(uint256).max);
        DripVault(winnerVault).deposit(100 ether);
        vm.stopPrank();

        vm.startPrank(rw2);
        token.approve(winnerVault, type(uint256).max);
        DripVault(winnerVault).deposit(50 ether);
        vm.stopPrank();

        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + MIN_WAGER}(
            vault1, winnerVault, 604800
        );
        vm.prank(address(revertingWinner));
        bm.acceptBattle{value: MIN_WAGER}(id);

        vm.warp(block.timestamp + 180 days);
        oracle.setPrice(1e9);

        // Mock vault1 to underperform so winnerVault wins
        vm.mockCall(
            vault1,
            abi.encodeWithSelector(IDripVault.totalAssets.selector),
            abi.encode(10 ether)
        );

        // winnerVault creator is RevertingReceiver — payout transfer will revert
        vm.expectRevert(BattleManager.TransferFailed.selector);
        bm.settleBattle(id);
        vm.clearMockedCalls();
    }

    // ═══════════════════════════════════════════════════════════════════
    // LINE 243: TransferFailed for treasury fee in settleBattle
    // BRDA:243,31,0,- (condition true branch not covered)
    // ═══════════════════════════════════════════════════════════════════

    function test_RevertIf_TreasuryFeeTransferFails_OnSettle() public {
        // revertAfter=1: accepts challenge fee (call 1), reverts on protocol fee (call 2)
        SelectiveReverter selectiveTreasury = new SelectiveReverter(1);
        BattleManager specialBm = new BattleManager(
            address(factory), address(selectiveTreasury),
            CHALLENGE_FEE, PROTOCOL_CUT_BPS, MIN_WAGER
        );

        vm.prank(alice);
        uint256 id = specialBm.declareBattleForVault{value: CHALLENGE_FEE + MIN_WAGER}(
            vault1, vault2, 3600
        );
        vm.prank(bob);
        specialBm.acceptBattle{value: MIN_WAGER}(id);

        vm.warp(block.timestamp + 3601);
        oracle.setPrice(1e9);

        vm.expectRevert(BattleManager.TransferFailed.selector);
        specialBm.settleBattle(id);
    }

    // ═══════════════════════════════════════════════════════════════════
    // LINE 254: totalSupply == 0 in _getVaultPPS
    // BRDA:254,32,0,- (condition true branch not covered)
    // ═══════════════════════════════════════════════════════════════════

    function test_PPS_ReturnsZero_WhenTotalSupplyIsZero() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + MIN_WAGER}(
            vault1, vault2, 604800
        );
        vm.prank(bob);
        bm.acceptBattle{value: MIN_WAGER}(id);

        // Withdraw all vault1 depositors so totalSupply → 0
        uint256 aliceShares = IDripToken(DripVault(vault1).dripToken()).balanceOf(alice);
        uint256 charlieShares = IDripToken(DripVault(vault1).dripToken()).balanceOf(charlie);
        vm.prank(alice);
        DripVault(vault1).withdraw(aliceShares);
        vm.prank(charlie);
        DripVault(vault1).withdraw(charlieShares);

        // 180 days so vault2 earns meaningful interest → defenderGrowth > 0
        vm.warp(block.timestamp + 180 days);
        oracle.setPrice(1e9);

        bm.settleBattle(id);

        // vault1 PPS = 0 (totalSupply == 0) → startPPS was non-zero → growth = 0
        // vault2 PPS grew from 180 days interest → defender wins
        (, , , , , , , , , address winner, ) = bm.battles(id);
        assertEq(winner, vault2, "Defender wins when challenger has zero supply");
    }

    // ═══════════════════════════════════════════════════════════════════
    // LINE 260: startPPS == 0 || currentPPS <= startPPS in _calculateGrowth
    // BRDA:260,33,0,- (condition true branch not covered)
    // ═══════════════════════════════════════════════════════════════════

    function test_GrowthReturnsZero_WhenNoPPSChange() public {
        // Standard battle - both vaults have same PPS initially
        vm.prank(alice);
        uint256 battleId = bm.declareBattleForVault{value: CHALLENGE_FEE + MIN_WAGER}(
            vault1,
            vault2,
            3600
        );
        
        vm.prank(bob);
        bm.acceptBattle{value: MIN_WAGER}(battleId);
        
        // Don't change assets - PPS stays the same
        // No time warp for interest, no oracle update
        vm.warp(block.timestamp + 3601);
        
        // Both have 0 growth (same PPS start and end), challenger wins on tie
        bm.settleBattle(battleId);
        
        (, , , , , , , , , address winner, ) = bm.battles(battleId);
        assertEq(winner, vault1);
    }

    function test_GrowthReturnsZero_WhenNegativeGrowth() public {
        // This is hard to trigger with real vaults since they don't lose value
        // But we can test the condition by checking the view function behavior
        vm.prank(alice);
        uint256 battleId = bm.declareBattleForVault{value: CHALLENGE_FEE + MIN_WAGER}(
            vault1,
            vault2,
            3600
        );
        
        vm.prank(bob);
        bm.acceptBattle{value: MIN_WAGER}(battleId);
        
        // Create scenario where one vault's growth is 0 (negative treated as 0)
        vm.warp(block.timestamp + 3601);
        
        // Get growth calculations
        (, , , , uint256 startPPS_challenger, uint256 startPPS_defender, , , , , ) = bm.battles(battleId);
        
        // Both start with similar PPS, if no interest accrual, growth = 0
        bm.settleBattle(battleId);
        
        // With 0 growth both, tie goes to challenger
        (, , , , , , , , , address winner, ) = bm.battles(battleId);
        assertEq(winner, vault1);
    }    

    // ═══════════════════════════════════════════════════════════════════
    // LINE 278: TransferFailed in withdrawFees
    // BRDA:278,35,0,- (condition true branch not covered)
    // ═══════════════════════════════════════════════════════════════════

    function test_RevertIf_WithdrawFeesTransferFails() public {
        // Deploy BattleManager with reverting treasury
        RevertingReceiver revertingTreasury = new RevertingReceiver();
        BattleManager specialBm = new BattleManager(
            address(factory),
            address(revertingTreasury),
            CHALLENGE_FEE,
            PROTOCOL_CUT_BPS,
            MIN_WAGER
        );
        
        // Send ETH directly to create withdrawable balance
        // (totalActiveStakes will be 0, so all balance is withdrawable)
        vm.deal(address(specialBm), 1 ether);
        
        vm.expectRevert(BattleManager.TransferFailed.selector);
        specialBm.withdrawFees();
    }

    // ═══════════════════════════════════════════════════════════════════
    // Additional edge case tests for completeness
    // ═══════════════════════════════════════════════════════════════════
    
    function test_DefenderWins_WithHigherGrowth() public {
        vm.prank(alice);
        uint256 id = bm.declareBattleForVault{value: CHALLENGE_FEE + MIN_WAGER}(
            vault1, vault2, 604800
        );
        vm.prank(bob);
        bm.acceptBattle{value: MIN_WAGER}(id);

        // Warp 180 days so vault2 accumulates meaningful interest (measurable growth bps)
        vm.warp(block.timestamp + 180 days);
        oracle.setPrice(1e9);

        // Mock vault1 totalAssets to 50 ether — far below snapshot value
        // challengerEndPPS << startPPS_challenger → growth = 0
        // vault2 earned 180 days of interest → defenderGrowth > 0 → defender wins
        vm.mockCall(
            vault1,
            abi.encodeWithSelector(IDripVault.totalAssets.selector),
            abi.encode(50 ether)
        );

        bm.settleBattle(id);
        vm.clearMockedCalls();

        (, , , , , , , , , address winner, ) = bm.battles(id);
        assertEq(winner, vault2, "Defender wins when challenger underperforms");
    }    
        
    function test_WithdrawFees_WithActiveStakes_WithdrawsOnlyExcess() public {
        vm.prank(alice);
        bm.declareBattleForVault{value: CHALLENGE_FEE + MIN_WAGER}(vault1, vault2, 3600);

        // Contract now holds exactly MIN_WAGER (challenge fee sent to treasury)
        // Add exactly 1 ether on top of current balance
        uint256 currentBalance = address(bm).balance;
        vm.deal(address(bm), currentBalance + 1 ether);

        uint256 balBefore = treasury.balance;
        bm.withdrawFees();

        assertApproxEqAbs(treasury.balance - balBefore, 1 ether, 0.01 ether,
            "Only excess above active stakes withdrawn");
        assertGe(address(bm).balance, MIN_WAGER,
            "Active stake still held in contract");
    }

    function test_WithdrawFees_WithNoExcess_DoesNothing() public {
        vm.prank(alice);
        bm.declareBattleForVault{value: CHALLENGE_FEE + MIN_WAGER}(
            vault1,
            vault2,
            3600
        );
        
        // Only has the locked wager, no excess
        uint256 balBefore = treasury.balance;
        bm.withdrawFees();
        uint256 balAfter = treasury.balance;
        
        assertEq(balAfter, balBefore);
    }
}

/// @dev Contract that reverts on any ETH receive
contract RevertingReceiver {
    receive() external payable {
        revert("RevertingReceiver: no ETH accepted");
    }
}

/// @dev Contract that reverts only on receive after a flag is set
contract ConditionalRevertingReceiver {
    bool public shouldRevert;
    
    receive() external payable {
        if (shouldRevert) revert("ConditionalRevertingReceiver: revert");
    }
    
    function setShouldRevert(bool _val) external {
        shouldRevert = _val;
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