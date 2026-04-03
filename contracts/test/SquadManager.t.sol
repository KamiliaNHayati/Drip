// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {SquadManager} from "../src/SquadManager.sol";

contract SquadManagerTest is Test {
    SquadManager public sm;

    address public treasury = makeAddr("treasury");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint256 constant CREATION_FEE = 10 ether;
    uint256 constant BOOST_FEE = 1 ether;

    function setUp() public {
        sm = new SquadManager(treasury, CREATION_FEE, BOOST_FEE, 10, 86400);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
    }

    function test_createSquad() public {
        vm.prank(alice);
        bytes32 id = sm.createSquad{value: CREATION_FEE}("Alpha Squad");

        assertTrue(sm.squadExists(id));
        assertEq(sm.userToSquad(alice), id);
        assertEq(sm.allSquadsLength(), 1);

        address[] memory members = sm.getSquadMembers(id);
        assertEq(members.length, 1);
        assertEq(members[0], alice);
    }

    function test_createSquad_insufficientFee_reverts() public {
        vm.expectRevert(SquadManager.InsufficientCreationFee.selector);
        vm.prank(alice);
        sm.createSquad{value: 1 ether}("Bad Squad");
    }

    function test_createSquad_duplicateName_reverts() public {
        vm.prank(alice);
        sm.createSquad{value: CREATION_FEE}("Alpha Squad");

        vm.expectRevert(SquadManager.SquadNameTaken.selector);
        vm.prank(bob);
        sm.createSquad{value: CREATION_FEE}("Alpha Squad");
    }

    function test_createSquad_alreadyInSquad_reverts() public {
        vm.prank(alice);
        sm.createSquad{value: CREATION_FEE}("Squad A");

        vm.expectRevert(SquadManager.AlreadyInSquad.selector);
        vm.prank(alice);
        sm.createSquad{value: CREATION_FEE}("Squad B");
    }

    function test_createSquad_feeGoesToTreasury() public {
        uint256 before = treasury.balance;
        vm.prank(alice);
        sm.createSquad{value: CREATION_FEE}("Fee Squad");
        assertEq(treasury.balance - before, CREATION_FEE);
    }

    function test_joinSquad() public {
        vm.prank(alice);
        bytes32 id = sm.createSquad{value: CREATION_FEE}("Join Squad");

        vm.prank(bob);
        sm.joinSquad(id);

        address[] memory members = sm.getSquadMembers(id);
        assertEq(members.length, 2);
        assertEq(sm.userToSquad(bob), id);
    }

    function test_joinSquad_alreadyIn_reverts() public {
        vm.prank(alice);
        bytes32 id = sm.createSquad{value: CREATION_FEE}("Dup Squad");

        vm.prank(bob);
        sm.joinSquad(id);

        vm.expectRevert(SquadManager.AlreadyInSquad.selector);
        vm.prank(bob);
        sm.joinSquad(id);
    }

    function test_joinSquad_full_reverts() public {
        vm.prank(alice);
        bytes32 id = sm.createSquad{value: CREATION_FEE}("Full Squad");

        // Fill to max (10 - 1 creator = 9 more)
        for (uint256 i = 0; i < 9; i++) {
            address member = address(uint160(5000 + i));
            vm.prank(member);
            sm.joinSquad(id);
        }

        vm.expectRevert(SquadManager.SquadFull.selector);
        vm.prank(makeAddr("overflow"));
        sm.joinSquad(id);
    }

    function test_leaveSquad() public {
        vm.prank(alice);
        bytes32 id = sm.createSquad{value: CREATION_FEE}("Leave Squad");

        vm.prank(bob);
        sm.joinSquad(id);

        vm.prank(bob);
        sm.leaveSquad();

        assertEq(sm.userToSquad(bob), bytes32(0));
        address[] memory members = sm.getSquadMembers(id);
        assertEq(members.length, 1);
    }

    function test_leaveSquad_notInSquad_reverts() public {
        vm.expectRevert(SquadManager.NotInSquad.selector);
        vm.prank(alice);
        sm.leaveSquad();
    }

    function test_activateBoost() public {
        vm.prank(alice);
        bytes32 id = sm.createSquad{value: CREATION_FEE}("Boost Squad");

        vm.prank(bob);
        sm.joinSquad(id);

        vm.prank(alice);
        sm.activateBoost{value: BOOST_FEE}(id);

        (uint256 memberCount, bool hasBoost, uint256 endsAt, uint256 boostBps) = sm.checkSquadStatus(id);
        assertEq(memberCount, 2);
        assertTrue(hasBoost);
        assertGt(endsAt, block.timestamp);
        assertEq(boostBps, 500); // +5% for 2 members
    }

    function test_activateBoost_3members_givesHigher() public {
        vm.prank(alice);
        bytes32 id = sm.createSquad{value: CREATION_FEE}("Big Squad");

        vm.prank(bob); 
        sm.joinSquad(id);
        vm.prank(charlie);
        sm.joinSquad(id);

        vm.prank(alice);
        sm.activateBoost{value: BOOST_FEE}(id);

        (, , , uint256 boostBps) = sm.checkSquadStatus(id);
        assertEq(boostBps, 1000); // +10% for 3+ members
    }

    function test_activateBoost_insufficientMembers_reverts() public {
        vm.prank(alice);
        bytes32 id = sm.createSquad{value: CREATION_FEE}("Solo Squad");

        vm.expectRevert(SquadManager.InsufficientMembers.selector);
        vm.prank(alice);
        sm.activateBoost{value: BOOST_FEE}(id);
    }

    function test_activateBoost_alreadyActive_reverts() public {
        vm.prank(alice);
        bytes32 id = sm.createSquad{value: CREATION_FEE}("Double Boost");

        vm.prank(bob);
        sm.joinSquad(id);

        vm.prank(alice);
        sm.activateBoost{value: BOOST_FEE}(id);

        vm.expectRevert(SquadManager.BoostAlreadyActive.selector);
        vm.prank(alice);
        sm.activateBoost{value: BOOST_FEE}(id);
    }

    function test_activateBoost_afterExpiry_succeeds() public {
        vm.prank(alice);
        bytes32 id = sm.createSquad{value: CREATION_FEE}("Re-Boost");

        vm.prank(bob);
        sm.joinSquad(id);

        vm.prank(alice);
        sm.activateBoost{value: BOOST_FEE}(id);

        // Warp past boost duration
        vm.warp(block.timestamp + 86401);

        // Should be able to activate again
        vm.prank(alice);
        sm.activateBoost{value: BOOST_FEE}(id);

        (, bool hasBoost, , ) = sm.checkSquadStatus(id);
        assertTrue(hasBoost);
    }

    function test_activateBoost_notMember_reverts() public {
        vm.prank(alice);
        bytes32 id = sm.createSquad{value: CREATION_FEE}("Member Boost");

        vm.prank(bob);
        sm.joinSquad(id);

        vm.expectRevert(SquadManager.NotInSquad.selector);
        vm.prank(charlie);
        sm.activateBoost{value: BOOST_FEE}(id);
    }

    function test_boostFee_goesToTreasury() public {
        vm.prank(alice);
        bytes32 id = sm.createSquad{value: CREATION_FEE}("Fee Boost");

        vm.prank(bob);
        sm.joinSquad(id);

        uint256 before = treasury.balance;
        vm.prank(alice);
        sm.activateBoost{value: BOOST_FEE}(id);
        assertEq(treasury.balance - before, BOOST_FEE);
    }

    function test_activateBoost_insufficientFee_reverts() public {
        vm.prank(alice);
        bytes32 id = sm.createSquad{value: CREATION_FEE}("Low Boost");

        vm.prank(bob);
        sm.joinSquad(id);

        vm.expectRevert(SquadManager.InsufficientBoostFee.selector);
        vm.prank(alice);
        sm.activateBoost{value: 0.1 ether}(id);
    }

    function test_joinSquad_nonExistent_reverts() public {
        vm.expectRevert(SquadManager.SquadNotFound.selector);
        vm.prank(alice);
        sm.joinSquad(bytes32(uint256(999)));
    }

    function test_setTreasuryAddress() public {
        address newTreasury = makeAddr("newTreasury");
        sm.setTreasuryAddress(newTreasury);
        assertEq(sm.treasury(), newTreasury);
    }

    function test_withdrawFees() public {
        // Send some INIT to SM
        vm.deal(address(sm), 5 ether);
        uint256 before = treasury.balance;
        sm.withdrawFees();
        assertEq(treasury.balance - before, 5 ether);
    }

    function test_checkSquadStatus_noBoost() public {
        vm.prank(alice);
        bytes32 id = sm.createSquad{value: CREATION_FEE}("No Boost");

        (uint256 memberCount, bool hasBoost, , uint256 boostBps) = sm.checkSquadStatus(id);
        assertEq(memberCount, 1);
        assertFalse(hasBoost);
        assertEq(boostBps, 0);
    }

    function test_activateBoost_nonExistent_reverts() public {
        vm.expectRevert(SquadManager.SquadNotFound.selector);
        vm.prank(alice);
        sm.activateBoost{value: BOOST_FEE}(bytes32(uint256(999)));
    }

        // ─── CREATE SQUAD MISSING BRANCHES ─────────────────────────────────

    /// @notice Covers Line 81: allSquadIds.length >= maxSquads
    function test_createSquad_limitReached_reverts() public {
        // maxSquads is hardcoded to 500, so we fill it up
        for (uint256 i = 0; i < 500; i++) {
            address member = address(uint160(1000 + i));
            vm.deal(member, CREATION_FEE);
            vm.prank(member);
            sm.createSquad{value: CREATION_FEE}(string(abi.encodePacked("Squad ", i)));
        }

        address overflow = address(uint160(9999));
        vm.deal(overflow, CREATION_FEE);
        vm.expectRevert(SquadManager.SquadLimitReached.selector);
        vm.prank(overflow);
        sm.createSquad{value: CREATION_FEE}("Overflow Squad");
    }

    /// @notice Covers Line 88: Treasury reverts on creation fee transfer
    function test_createSquad_treasuryRevert_transferFailed() public {
        SquadManager badTreasurySm = new SquadManager(
            address(new RevertingReceiver()), CREATION_FEE, BOOST_FEE, 10, 86400
        );

        vm.prank(alice);
        vm.expectRevert(SquadManager.TransferFailed.selector);
        badTreasurySm.createSquad{value: CREATION_FEE}("Bad Treasury");
    }

    /// @notice Covers Line 91: User reverts on excess fee refund
    function test_createSquad_refundRevert_transferFailed() public {
        RevertingReceiver sender = new RevertingReceiver();
        vm.deal(address(sender), CREATION_FEE + 1 ether); // MUST be > CREATION_FEE

        vm.prank(address(sender));
        vm.expectRevert(SquadManager.TransferFailed.selector);
        sm.createSquad{value: CREATION_FEE + 1 ether}("Refund Fail Squad"); // Send excess
    }

    // ─── LEAVE SQUAD MISSING BRANCH ────────────────────────────────────

    /// @notice Covers Line 129: msg.sender == squad.creator
    function test_leaveSquad_creatorCannotLeave_reverts() public {
        vm.prank(alice);
        sm.createSquad{value: CREATION_FEE}("Creator Squad");

        vm.expectRevert(SquadManager.CreatorCannotLeave.selector);
        vm.prank(alice);
        sm.leaveSquad();
    }

    // ─── ACTIVATE BOOST MISSING BRANCHES ───────────────────────────────

    /// @notice Covers Line 159: Treasury reverts on boost fee transfer
    function test_activateBoost_treasuryRevert_transferFailed() public {
        vm.prank(alice);
        bytes32 id = sm.createSquad{value: CREATION_FEE}("Boost Bad Treasury");

        vm.prank(bob);
        sm.joinSquad(id);

        // Switch treasury to a reverting receiver AFTER squad creation
        sm.setTreasuryAddress(address(new RevertingReceiver()));

        vm.prank(alice);
        vm.expectRevert(SquadManager.TransferFailed.selector);
        sm.activateBoost{value: BOOST_FEE}(id);
    }

    /// @notice Covers Line 162: User reverts on excess boost fee refund
    function test_activateBoost_refundRevert_transferFailed() public {
        RevertingReceiver sender = new RevertingReceiver();
        vm.deal(address(sender), 2 ether);

        vm.prank(alice);
        bytes32 id = sm.createSquad{value: CREATION_FEE}("Refund Boost Squad");

        vm.prank(address(sender));
        sm.joinSquad(id);

        vm.prank(address(sender));
        vm.expectRevert(SquadManager.TransferFailed.selector);
        sm.activateBoost{value: 2 ether}(id);
    }

    // ─── WITHDRAW FEES MISSING BRANCHES ────────────────────────────────

    /// @notice Covers Line 181: bal == 0 early return
    function test_withdrawFees_zeroBalance_doesNothing() public {
        // address(this) deployed the SquadManager, so it is the owner.
        // sm balance is 0 by default since fees go straight to treasury.
        sm.withdrawFees(); // Should not revert, just return
        assertEq(address(sm).balance, 0);
    }

    /// @notice Covers Line 183: Treasury reverts on withdrawFees
    function test_withdrawFees_treasuryRevert_transferFailed() public {
        // Set treasury to a reverting receiver
        sm.setTreasuryAddress(address(new RevertingReceiver()));

        // Force some ETH into the SquadManager contract directly
        vm.deal(address(sm), 1 ether);

        vm.expectRevert(SquadManager.TransferFailed.selector);
        sm.withdrawFees();
    }
}

contract RevertingReceiver {
    receive() external payable {
        revert();
    }
}