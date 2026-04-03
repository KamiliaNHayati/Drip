// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SquadManager — Social yield multiplier squads
/// @notice Form squads, activate yield boost (UI projection only — on-chain yield unchanged).
/// @dev Non-clone contract. Boost is cosmetic for MVP.
contract SquadManager is Ownable, ReentrancyGuard {

    // ─── Events ────────────────────────────────────────────────────────
    event SquadCreated(bytes32 indexed id, string name, address indexed creator);
    event MemberJoined(bytes32 indexed id, address indexed member);
    event MemberLeft(bytes32 indexed id, address indexed member);
    event BoostActivated(bytes32 indexed id, uint256 memberCount, uint256 boostEndsAt);
    event TreasuryUpdated(address indexed newTreasury);

    // ─── Errors ────────────────────────────────────────────────────────
    error SquadNameTaken();
    error SquadFull();
    error AlreadyInSquad();
    error NotInSquad();
    error InsufficientBoostFee();
    error BoostAlreadyActive();
    error InsufficientCreationFee();
    error SquadNotFound();
    error InsufficientMembers();
    error TransferFailed();
    error CreatorCannotLeave();
    error SquadLimitReached();

    // ─── Structs ───────────────────────────────────────────────────────
    struct Squad {
        bytes32 id;
        string name;
        address creator;
        address[] members;
        uint256 createdAt;
        uint256 boostEndsAt;
    }

    // ─── Storage ───────────────────────────────────────────────────────
    mapping(bytes32 => Squad) public squads;
    mapping(address => bytes32) public userToSquad;
    mapping(bytes32 => bool) public squadExists;
    bytes32[] public allSquadIds;

    uint256 public creationFee;
    uint256 public boostFee;
    uint256 public maxMembers;
    uint256 public maxSquads;
    uint256 public boostDuration;
    address public treasury;

    // ─── Constructor ───────────────────────────────────────────────────

    /// @notice Deploy the squad manager
    constructor(
        address _treasury,
        uint256 _creationFee,
        uint256 _boostFee,
        uint256 _maxMembers,
        uint256 _boostDuration
    ) Ownable(msg.sender) {
        treasury = _treasury;
        creationFee = _creationFee;
        boostFee = _boostFee;
        maxMembers = _maxMembers;
        maxSquads = 500;
        boostDuration = _boostDuration;
    }

    // ─── Core ──────────────────────────────────────────────────────────

    /// @notice Create a new squad
    /// @param _name Squad name (max 32 chars enforced via bytes32 hash uniqueness)
    function createSquad(string calldata _name) external payable nonReentrant returns (bytes32 squadId) {
        if (msg.value < creationFee) revert InsufficientCreationFee();
        if (userToSquad[msg.sender] != bytes32(0)) revert AlreadyInSquad();
        if (allSquadIds.length >= maxSquads) revert SquadLimitReached();

        squadId = keccak256(abi.encodePacked(_name));
        if (squadExists[squadId]) revert SquadNameTaken();

        // Send creation fee to treasury (refund excess)
        (bool s, ) = payable(treasury).call{value: creationFee}("");
        if (!s) revert TransferFailed();
        if (msg.value > creationFee) {
            (bool r, ) = payable(msg.sender).call{value: msg.value - creationFee}("");
            if (!r) revert TransferFailed();
        }

        Squad storage squad = squads[squadId];
        squad.id = squadId;
        squad.name = _name;
        squad.creator = msg.sender;
        squad.members.push(msg.sender);
        squad.createdAt = block.timestamp;

        squadExists[squadId] = true;
        userToSquad[msg.sender] = squadId;
        allSquadIds.push(squadId);

        emit SquadCreated(squadId, _name, msg.sender);
        emit MemberJoined(squadId, msg.sender);
    }

    /// @notice Join an existing squad
    function joinSquad(bytes32 squadId) external {
        if (!squadExists[squadId]) revert SquadNotFound();
        if (userToSquad[msg.sender] != bytes32(0)) revert AlreadyInSquad();

        Squad storage squad = squads[squadId];
        if (squad.members.length >= maxMembers) revert SquadFull();

        squad.members.push(msg.sender);
        userToSquad[msg.sender] = squadId;

        emit MemberJoined(squadId, msg.sender);
    }

    /// @notice Leave your current squad (creator cannot leave)
    function leaveSquad() external {
        bytes32 squadId = userToSquad[msg.sender];
        if (squadId == bytes32(0)) revert NotInSquad();

        Squad storage squad = squads[squadId];
        if (msg.sender == squad.creator) revert CreatorCannotLeave();

        // Remove member from array
        uint256 len = squad.members.length;
        for (uint256 i = 0; i < len; i++) {
            if (squad.members[i] == msg.sender) {
                squad.members[i] = squad.members[len - 1];
                squad.members.pop();
                break;
            }
        }

        userToSquad[msg.sender] = bytes32(0);
        emit MemberLeft(squadId, msg.sender);
    }

    /// @notice Activate a yield boost for the squad (UI projection only)
    function activateBoost(bytes32 squadId) external payable nonReentrant {
        if (!squadExists[squadId]) revert SquadNotFound();
        if (msg.value < boostFee) revert InsufficientBoostFee();

        Squad storage squad = squads[squadId];
        if (squad.members.length < 2) revert InsufficientMembers();
        if (squad.boostEndsAt > block.timestamp) revert BoostAlreadyActive();

        // Must be a member
        if (userToSquad[msg.sender] != squadId) revert NotInSquad();

        // Send boost fee to treasury (refund excess)
        (bool s, ) = payable(treasury).call{value: boostFee}("");
        if (!s) revert TransferFailed();
        if (msg.value > boostFee) {
            (bool r, ) = payable(msg.sender).call{value: msg.value - boostFee}("");
            if (!r) revert TransferFailed();
        }

        squad.boostEndsAt = block.timestamp + boostDuration;

        emit BoostActivated(squadId, squad.members.length, squad.boostEndsAt);
    }

    // ─── Admin ─────────────────────────────────────────────────────────

    /// @notice Update treasury
    function setTreasuryAddress(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    /// @notice Withdraw stuck funds
    function withdrawFees() external onlyOwner {
        uint256 bal = address(this).balance;
        if (bal == 0) return;
        (bool s, ) = payable(treasury).call{value: bal}("");
        if (!s) revert TransferFailed();
    }

    // ─── View ──────────────────────────────────────────────────────────

    /// @notice Get squad status
    function checkSquadStatus(bytes32 squadId) external view returns (
        uint256 memberCount,
        bool hasActiveBoost,
        uint256 _boostEndsAt,
        uint256 projectedBoostBps
    ) {
        Squad storage squad = squads[squadId];
        memberCount = squad.members.length;
        _boostEndsAt = squad.boostEndsAt;
        hasActiveBoost = squad.boostEndsAt > block.timestamp;

        if (hasActiveBoost) {
            projectedBoostBps = memberCount >= 3 ? 1000 : 500; // +10% for 3+, +5% for 2
        }
    }

    /// @notice Get squad members
    function getSquadMembers(bytes32 squadId) external view returns (address[] memory) {
        return squads[squadId].members;
    }

    /// @notice Get total squads count
    function allSquadsLength() external view returns (uint256) {
        return allSquadIds.length;
    }
}
