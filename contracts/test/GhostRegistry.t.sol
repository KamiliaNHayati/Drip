// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {GhostRegistry} from "../src/GhostRegistry.sol";

contract GhostRegistryTest is Test {
    GhostRegistry public registry;

    address public treasury = makeAddr("treasury");
    address public ghost1 = makeAddr("ghost1");
    address public ghost2 = makeAddr("ghost2");
    address public vault = makeAddr("vault"); // simulates a DripVault calling

    function setUp() public {
        registry = new GhostRegistry(treasury, 10, 1000); // 0.1% fee, 10% protocol
        registry.authorizeVault(vault);
    }

    function test_registerAsGhost() public {
        vm.prank(ghost1);
        registry.registerAsGhost();

        assertTrue(registry.registeredGhosts(ghost1));
        assertEq(registry.ghostListLength(), 1);
    }

    function test_registerAsGhost_alreadyRegistered_reverts() public {
        vm.prank(ghost1);
        registry.registerAsGhost();

        vm.expectRevert(GhostRegistry.AlreadyRegistered.selector);
        vm.prank(ghost1);
        registry.registerAsGhost();
    }

    function test_registerAsGhost_maxList() public {
        for (uint256 i = 0; i < 100; i++) {
            address g = address(uint160(3000 + i));
            vm.prank(g);
            registry.registerAsGhost();
        }

        vm.expectRevert(GhostRegistry.GhostListFull.selector);
        vm.prank(makeAddr("overflow"));
        registry.registerAsGhost();
    }

    function test_recordCompound_success() public {
        vm.prank(ghost1);
        registry.registerAsGhost();

        // Vault calls recordCompound
        vm.prank(vault);
        uint256 fee = registry.recordCompound(ghost1, 1000 ether);

        // 0.1% of 1000 = 1 INIT
        assertEq(fee, 1 ether);

        // Ghost gets 90% of fee = 0.9 INIT as pending
        (uint256 compoundsExec, uint256 successComp, uint256 totalYield, uint256 pending, uint256 totalFees, ) =
            registry.ghostStats(ghost1);
        assertEq(compoundsExec, 1);
        assertEq(successComp, 1);
        assertEq(totalYield, 1000 ether);
        assertEq(pending, 0.9 ether);   // 90% of 1 INIT
        assertEq(totalFees, 0.9 ether);

        // Protocol gets 10% = 0.1 INIT
        assertEq(registry.protocolAccrued(), 0.1 ether);
    }

    function test_recordCompound_notRegistered_reverts() public {
        vm.expectRevert(GhostRegistry.NotRegisteredGhost.selector);
        vm.prank(vault);
        registry.recordCompound(ghost1, 1000 ether);
    }

    function test_reliabilityScore() public {
        vm.prank(ghost1);
        registry.registerAsGhost();

        vm.startPrank(vault);
        registry.recordCompound(ghost1, 100 ether);
        registry.recordCompound(ghost1, 200 ether);
        registry.recordCompound(ghost1, 300 ether);
        vm.stopPrank();

        // 3/3 successful = 10000 bps (100%)
        assertEq(registry.reliabilityScore(ghost1), 10000);
    }

    function test_reliabilityScore_noCompounds() public view {
        assertEq(registry.reliabilityScore(ghost1), 0);
    }

    function test_getTopGhosts() public {
        vm.prank(ghost1);
        registry.registerAsGhost();
        vm.prank(ghost2);
        registry.registerAsGhost();

        vm.startPrank(vault);
        registry.recordCompound(ghost1, 100 ether);
        registry.recordCompound(ghost2, 500 ether); // ghost2 manages more
        vm.stopPrank();

        (address[] memory ghosts, uint256[] memory yields) = registry.getTopGhosts(2);
        assertEq(ghosts[0], ghost2); // ghost2 first (more yield)
        assertEq(ghosts[1], ghost1);
        assertEq(yields[0], 500 ether);
        assertEq(yields[1], 100 ether);
    }

    function test_claimGhostRewards() public {
        vm.prank(ghost1);
        registry.registerAsGhost();

        vm.prank(vault);
        registry.recordCompound(ghost1, 1000 ether);

        vm.prank(ghost1);
        registry.claimGhostRewards();

        (, , , uint256 pending, , ) = registry.ghostStats(ghost1);
        assertEq(pending, 0);
    }

    function test_claimGhostRewards_nothingToClaim_reverts() public {
        vm.prank(ghost1);
        registry.registerAsGhost();

        vm.expectRevert(GhostRegistry.NothingToClaim.selector);
        vm.prank(ghost1);
        registry.claimGhostRewards();
    }

    function test_recordCompound_unauthorizedVault_reverts() public {
        vm.prank(ghost1);
        registry.registerAsGhost();

        address fakeVault = makeAddr("fakeVault");
        vm.expectRevert(GhostRegistry.NotAuthorizedVault.selector);
        vm.prank(fakeVault);
        registry.recordCompound(ghost1, 1000 ether);
    }

    function test_revokeVault() public {
        vm.prank(ghost1);
        registry.registerAsGhost();

        // vault is authorized in setUp
        vm.prank(vault);
        registry.recordCompound(ghost1, 100 ether); // works

        // Revoke
        registry.revokeVault(vault);

        vm.expectRevert(GhostRegistry.NotAuthorizedVault.selector);
        vm.prank(vault);
        registry.recordCompound(ghost1, 100 ether); // now fails
    }

    function test_setTreasuryAddress() public {
        address newTreasury = makeAddr("newTreasury");
        registry.setTreasuryAddress(newTreasury);
        assertEq(registry.treasury(), newTreasury);
    }

    function test_withdrawFees() public {
        vm.prank(ghost1);
        registry.registerAsGhost();

        vm.prank(vault);
        registry.recordCompound(ghost1, 1000 ether);

        uint256 before = registry.protocolAccrued();
        assertGt(before, 0);

        registry.withdrawFees();
        assertEq(registry.protocolAccrued(), 0);
    }

    function test_recordCompound_zeroYield() public {
        vm.prank(ghost1);
        registry.registerAsGhost();

        vm.prank(vault);
        uint256 fee = registry.recordCompound(ghost1, 0);
        assertEq(fee, 0);
    }
}
