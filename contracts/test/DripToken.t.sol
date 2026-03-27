// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DripToken} from "../src/DripToken.sol";

/// @title DripToken Test Suite
contract DripTokenTest is Test {
    DripToken public token;

    address public vault = makeAddr("vault");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        token = new DripToken();
        token.initialize(vault, "dripTestVault", "dTEST");
    }

    // ─── Initialize Tests ──────────────────────────────────────────────

    function test_initialize_setsCorrectly() public view {
        assertEq(token.vault(), vault);
        assertEq(token.name(), "dripTestVault");
        assertEq(token.symbol(), "dTEST");
    }

    function test_initialize_once() public {
        vm.expectRevert();  // OZ Initializable reverts with InvalidInitialization()
        token.initialize(alice, "dripAnother", "dANOTHER");
    }

    // ─── Mint/Burn Tests ───────────────────────────────────────────────

    function test_onlyVaultCanMint() public {
        vm.prank(vault);
        token.mint(alice, 100 ether);

        assertEq(token.balanceOf(alice), 100 ether);
        assertEq(token.totalSupply(), 100 ether);
    }

    function test_mint_notVault_reverts() public {
        vm.expectRevert(DripToken.OnlyVault.selector);
        vm.prank(alice);
        token.mint(alice, 100 ether);
    }

    function test_onlyVaultCanBurn() public {
        vm.prank(vault);
        token.mint(alice, 100 ether);

        vm.prank(vault);
        token.burn(alice, 50 ether);

        assertEq(token.balanceOf(alice), 50 ether);
        assertEq(token.totalSupply(), 50 ether);
    }

    function test_burn_notVault_reverts() public {
        vm.prank(vault);
        token.mint(alice, 100 ether);

        vm.expectRevert(DripToken.OnlyVault.selector);
        vm.prank(alice);
        token.burn(alice, 50 ether);
    }

    // ─── Transfer Tests ────────────────────────────────────────────────

    function test_transferWorks() public {
        vm.prank(vault);
        token.mint(alice, 100 ether);

        vm.prank(alice);
        token.transfer(bob, 30 ether);

        assertEq(token.balanceOf(alice), 70 ether);
        assertEq(token.balanceOf(bob), 30 ether);
    }

    function test_approveAndTransferFrom() public {
        vm.prank(vault);
        token.mint(alice, 100 ether);

        vm.prank(alice);
        token.approve(bob, 50 ether);

        vm.prank(bob);
        token.transferFrom(alice, bob, 50 ether);

        assertEq(token.balanceOf(alice), 50 ether);
        assertEq(token.balanceOf(bob), 50 ether);
    }
}
