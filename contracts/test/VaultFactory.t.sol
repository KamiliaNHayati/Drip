// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DripPool} from "../src/DripPool.sol";
import {DripToken} from "../src/DripToken.sol";
import {DripVault} from "../src/DripVault.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {IDripVault} from "../src/interfaces/IDripVault.sol";
import {IDripToken} from "../src/interfaces/IDripToken.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {MockOracle} from "./mocks/MockOracle.sol";


/// @title VaultFactory Test Suite
contract VaultFactoryTest is Test {
    DripPool public pool;
    DripToken public tokenImpl;
    DripVault public vaultImpl;
    VaultFactory public factory;
    ERC20Mock public token;
    MockOracle public oracle;

    address public treasury = makeAddr("treasury");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 constant CREATION_FEE = 3 ether;
    uint256 constant DRIP_CUT_BPS = 1000; // 10%

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

        // Deploy implementation contracts (templates for cloning)
        tokenImpl = new DripToken();
        vaultImpl = new DripVault();

        // Deploy factory
        factory = new VaultFactory(
            address(vaultImpl),
            address(tokenImpl),
            address(pool),
            address(oracle),
            treasury,
            CREATION_FEE,
            DRIP_CUT_BPS
        );

        // Fund alice and bob with native INIT for creation fees
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    // ─── Clone Init Order ──────────────────────────────────────────────

    function test_createVault_tokenFirst_vaultSecond() public {
        vm.prank(alice);
        (address vault, address _token) = factory.createVault{value: CREATION_FEE}(
            "Alpha", "Alpha vault", 1000
        );

        // Both addresses should be non-zero and different
        assertTrue(vault != address(0), "Vault should be deployed");
        assertTrue(_token != address(0), "Token should be deployed");
        assertTrue(vault != _token, "Vault and token should be different");

        // Token clone address should be lower than vault due to create order
        // (token cloned first → lower nonce → lower address)
        assertTrue(uint160(_token) < uint160(vault), "Token should be deployed before vault");
    }

    function test_createVault_tokenAddressInVault() public {
        vm.prank(alice);
        (address vault, address _token) = factory.createVault{value: CREATION_FEE}(
            "Beta", "Beta vault", 1000
        );

        // Vault's dripToken should point to the created token
        assertEq(IDripVault(vault).dripToken(), _token, "Vault dripToken should match created token");
    }

    function test_createVault_vaultAddressInToken() public {
        vm.prank(alice);
        (address vault, address _token) = factory.createVault{value: CREATION_FEE}(
            "Gamma", "Gamma vault", 1000
        );

        // Token's vault should point to the created vault
        assertEq(DripToken(_token).vault(), vault, "Token vault should match created vault");
    }

    // ─── Fee Validation ────────────────────────────────────────────────

    function test_createVault_insufficientFee() public {
        vm.expectRevert(VaultFactory.InsufficientCreationFee.selector);
        vm.prank(alice);
        factory.createVault{value: 1 ether}("Bad", "under-fee", 1000);
    }

    function test_createVault_invalidCreatorFee_tooLow() public {
        vm.expectRevert(VaultFactory.InvalidCreatorFee.selector);
        vm.prank(alice);
        factory.createVault{value: CREATION_FEE}("Bad", "fee too low", 499);
    }

    function test_createVault_invalidCreatorFee_tooHigh() public {
        vm.expectRevert(VaultFactory.InvalidCreatorFee.selector);
        vm.prank(alice);
        factory.createVault{value: CREATION_FEE}("Bad", "fee too high", 2001);
    }

    // ─── Fee Transfer ──────────────────────────────────────────────────

    function test_createVault_feeGoesToTreasury() public {
        uint256 treasuryBefore = treasury.balance;

        vm.prank(alice);
        factory.createVault{value: CREATION_FEE}("Funded", "fee test", 1000);

        assertEq(treasury.balance - treasuryBefore, CREATION_FEE, "Treasury should receive exactly 3 INIT");
    }

    // ─── Tracking ──────────────────────────────────────────────────────

    function test_multipleVaults_tracked() public {
        vm.prank(alice);
        (address vault1, address token1) = factory.createVault{value: CREATION_FEE}(
            "V1", "vault 1", 1000
        );

        vm.prank(alice);
        (address vault2, address token2) = factory.createVault{value: CREATION_FEE}(
            "V2", "vault 2", 500
        );

        vm.prank(bob);
        (address vault3, address token3) = factory.createVault{value: CREATION_FEE}(
            "V3", "vault 3", 2000
        );

        // allVaults tracking
        assertEq(factory.allVaultsLength(), 3, "Should have 3 vaults total");
        assertEq(factory.allVaults(0), vault1);
        assertEq(factory.allVaults(1), vault2);
        assertEq(factory.allVaults(2), vault3);

        // vaultsByCreator tracking
        assertEq(factory.vaultsByCreatorLength(alice), 2, "Alice should have 2 vaults");
        assertEq(factory.vaultsByCreatorLength(bob), 1, "Bob should have 1 vault");

        // vaultToToken mapping
        assertEq(factory.vaultToToken(vault1), token1);
        assertEq(factory.vaultToToken(vault2), token2);
        assertEq(factory.vaultToToken(vault3), token3);

        // isRegisteredVault
        assertTrue(factory.isRegisteredVault(vault1));
        assertTrue(factory.isRegisteredVault(vault2));
        assertTrue(factory.isRegisteredVault(vault3));
        assertFalse(factory.isRegisteredVault(address(0xdead)));
    }

    // ─── Fuzz ──────────────────────────────────────────────────────────

    function testFuzz_creatorFee(uint256 fee) public {
        fee = bound(fee, 500, 2000);

        vm.prank(alice);
        (address vault,) = factory.createVault{value: CREATION_FEE}(
            "Fuzz", "fuzz vault", fee
        );

        assertEq(IDripVault(vault).creatorFeeBps(), fee, "Creator fee should match input");
    }

    // ─── Vault Functionality Post-Clone ────────────────────────────────

    function test_clonedVault_canDeposit() public {
        vm.prank(alice);
        (address vault, address dripTok) = factory.createVault{value: CREATION_FEE}(
            "Deposit", "deposit test", 1000
        );

        // Mint tokens and deposit into cloned vault
        token.mint(bob, 100 ether);
        vm.startPrank(bob);
        token.approve(vault, type(uint256).max);
        DripVault(vault).deposit(100 ether);
        vm.stopPrank();

        assertGt(IDripToken(dripTok).balanceOf(bob), 0, "Bob should have receipt tokens");
        assertEq(IDripVault(vault).depositorCount(), 1, "Depositor count should be 1");
    }

    // ─── Admin ──────────────────────────────────────────────────────────

    function test_setTreasuryAddress() public {
        address newTreasury = makeAddr("newTreasury");
        factory.setTreasuryAddress(newTreasury);
        assertEq(factory.treasury(), newTreasury);
    }

    function test_setTreasuryAddress_zero_reverts() public {
        vm.expectRevert(VaultFactory.InvalidAddress.selector);
        factory.setTreasuryAddress(address(0));
    }

    function test_setTreasuryAddress_notOwner_reverts() public {
        vm.expectRevert();
        vm.prank(alice);
        factory.setTreasuryAddress(makeAddr("bad"));
    }

    function test_withdrawFees() public {
        // Send some INIT to factory
        vm.deal(address(factory), 5 ether);
        uint256 treasuryBefore = treasury.balance;
        factory.withdrawFees();
        assertEq(treasury.balance - treasuryBefore, 5 ether);
        assertEq(address(factory).balance, 0);
    }

    function test_withdrawFees_empty() public {
        // Nothing to withdraw — should silently return
        factory.withdrawFees();
    }

    function test_isRegisteredVault_false() public view {
        assertFalse(factory.isRegisteredVault(address(0xdead)));
        assertFalse(factory.isRegisteredVault(address(0)));
    }

    function test_createVault_overpayment_refunded() public {
        uint256 aliceBefore = alice.balance;
        vm.prank(alice);
        factory.createVault{value: CREATION_FEE + 5 ether}("Refund", "test refund", 1000);

        // Should only spend CREATION_FEE (excess refunded)
        assertEq(aliceBefore - alice.balance, CREATION_FEE);
    }

    function test_vaultsByCreator_view() public {
        vm.prank(alice);
        factory.createVault{value: CREATION_FEE}("A1", "a1", 1000);
        vm.prank(alice);
        factory.createVault{value: CREATION_FEE}("A2", "a2", 1500);
        vm.prank(bob);
        factory.createVault{value: CREATION_FEE}("B1", "b1", 800);

        assertEq(factory.vaultsByCreatorLength(alice), 2);
        assertEq(factory.vaultsByCreatorLength(bob), 1);
        assertEq(factory.vaultsByCreatorLength(makeAddr("nobody")), 0);
    }

    // ─── CONSTRUCTOR MISSING BRANCHES ──────────────────────────────────

    /// @notice Covers Lines 56 & 57: Constructor reverts on address(0)
    function test_constructor_invalidAddress_reverts() public {
        // Line 56: _vaultImpl == address(0)
        vm.expectRevert(VaultFactory.InvalidAddress.selector);
        new VaultFactory(
            address(0), address(tokenImpl), address(pool), address(oracle), treasury, CREATION_FEE, DRIP_CUT_BPS
        );

        // Line 56: _tokenImpl == address(0)
        vm.expectRevert(VaultFactory.InvalidAddress.selector);
        new VaultFactory(
            address(vaultImpl), address(0), address(pool), address(oracle), treasury, CREATION_FEE, DRIP_CUT_BPS
        );

        // Line 57: _dripPool == address(0)
        vm.expectRevert(VaultFactory.InvalidAddress.selector);
        new VaultFactory(
            address(vaultImpl), address(tokenImpl), address(0), address(oracle), treasury, CREATION_FEE, DRIP_CUT_BPS
        );

        // Line 57: _treasury == address(0)
        vm.expectRevert(VaultFactory.InvalidAddress.selector);
        new VaultFactory(
            address(vaultImpl), address(tokenImpl), address(pool), address(oracle), address(0), CREATION_FEE, DRIP_CUT_BPS
        );
    }

    // ─── CREATE VAULT MISSING BRANCHES ─────────────────────────────────

    /// @notice Covers Line 115: Treasury reverts on fee transfer
    function test_createVault_treasuryRevert_transferFailed() public {
        // Switch factory treasury to a reverting receiver
        RevertingReceiver badTreasury = new RevertingReceiver();
        factory.setTreasuryAddress(address(badTreasury));

        vm.prank(alice);
        vm.expectRevert(VaultFactory.TransferFailed.selector);
        factory.createVault{value: CREATION_FEE}("Bad Treasury", "test", 1000);
    }

    /// @notice Covers Line 118: User reverts on excess fee refund
    function test_createVault_refundRevert_transferFailed() public {
        // Make the sender a contract that reverts when receiving ETH
        RevertingReceiver sender = new RevertingReceiver();
        vm.deal(address(sender), CREATION_FEE + 1 ether); // Fund with excess

        vm.prank(address(sender));
        vm.expectRevert(VaultFactory.TransferFailed.selector);
        factory.createVault{value: CREATION_FEE + 1 ether}("Refund Fail", "test", 1000);
    }

    // ─── WITHDRAW FEES MISSING BRANCH ──────────────────────────────────

    /// @notice Covers Line 143: Treasury reverts on withdrawFees
    function test_withdrawFees_treasuryRevert_transferFailed() public {
        // Switch treasury to a reverting receiver
        RevertingReceiver badTreasury = new RevertingReceiver();
        factory.setTreasuryAddress(address(badTreasury));

        // Force some ETH into the factory (bypassing normal fee flow)
        vm.deal(address(factory), 1 ether);

        vm.expectRevert(VaultFactory.TransferFailed.selector);
        factory.withdrawFees();
    }

}

contract RevertingReceiver {
    receive() external payable {
        revert();
    }
}