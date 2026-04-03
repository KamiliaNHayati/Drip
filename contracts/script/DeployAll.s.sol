// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DripPool} from "../src/DripPool.sol";
import {DripToken} from "../src/DripToken.sol";
import {DripVault} from "../src/DripVault.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {CompetitionManager} from "../src/CompetitionManager.sol";
import {BattleManager} from "../src/BattleManager.sol";
import {GhostRegistry} from "../src/GhostRegistry.sol";
import {SquadManager} from "../src/SquadManager.sol";

/// @title Deploy All Drip Contracts
/// @notice Deploys all 8 contracts: Pool, Token, Vault, Factory, Competition, Battle, Ghost, Squad
/// @dev Run: forge script script/DeployAll.s.sol --rpc-url $RPC --account Initia1 --broadcast --via-ir
contract DeployAll is Script {
    // ─── Constants ─────────────────────────────────────────────────────
    address constant INIT_TOKEN = 0x2eE7007DF876084d4C74685e90bB7f4cd7c86e22;
    address constant CONNECT_ORACLE = 0x031ECb63480983FD216D17BB6e1d393f3816b72F;

    // DripPool params
    uint256 constant INTEREST_RATE_BPS = 800;     // 8% APY
    uint256 constant RESERVE_FACTOR_BPS = 1000;   // 10%
    uint256 constant LIQ_PENALTY_BPS = 1000;      // 10%
    uint256 constant LIQ_PROTOCOL_BPS = 5000;     // 50% of penalty to protocol
    uint256 constant COLLATERAL_FACTOR_BPS = 7500; // 75% LTV

    // VaultFactory params
    uint256 constant CREATION_FEE = 3 ether;
    uint256 constant DRIP_CUT_BPS = 1000;         // 10%

    // CompetitionManager params
    uint256 constant ENTRY_FEE = 7 ether;
    uint256 constant PROTOCOL_SEED = 23 ether;

    // BattleManager params
    uint256 constant CHALLENGE_FEE = 40 ether;
    uint256 constant BATTLE_PROTOCOL_CUT_BPS = 2000; // 20%
    uint256 constant MIN_WAGER = 10 ether;

    // GhostRegistry params
    uint256 constant PERFORMANCE_FEE_BPS = 10;    // 0.1%
    uint256 constant GHOST_PROTOCOL_SHARE_BPS = 1000; // 10%

    // SquadManager params
    uint256 constant SQUAD_CREATION_FEE = 10 ether;
    uint256 constant BOOST_FEE = 1 ether;
    uint256 constant MAX_MEMBERS = 10;
    uint256 constant BOOST_DURATION = 86400; // 24 hours

    function run() external {
        address deployer = msg.sender;
        address treasury = deployer; // treasury = deployer for testnet

        console.log("Deployer:", deployer);
        console.log("Treasury:", treasury);
        console.log("INIT Token:", INIT_TOKEN);
        console.log("Oracle:", CONNECT_ORACLE);

        vm.startBroadcast();

        // 1. Deploy DripPool
        DripPool pool = new DripPool(
            INIT_TOKEN,
            treasury,
            INTEREST_RATE_BPS,
            RESERVE_FACTOR_BPS,
            LIQ_PENALTY_BPS,
            LIQ_PROTOCOL_BPS,
            COLLATERAL_FACTOR_BPS
        );
        console.log("DripPool:", address(pool));

        // 2. Deploy DripToken implementation (template for cloning)
        DripToken tokenImpl = new DripToken();
        console.log("DripToken impl:", address(tokenImpl));

        // 3. Deploy DripVault implementation (template for cloning)
        DripVault vaultImpl = new DripVault();
        console.log("DripVault impl:", address(vaultImpl));

        // 4. Deploy VaultFactory
        VaultFactory factory = new VaultFactory(
            address(vaultImpl),
            address(tokenImpl),
            address(pool),
            CONNECT_ORACLE,
            treasury,
            CREATION_FEE,
            DRIP_CUT_BPS
        );
        console.log("VaultFactory:", address(factory));

        // 5. Deploy CompetitionManager
        CompetitionManager cm = new CompetitionManager(
            address(factory),
            treasury,
            ENTRY_FEE,
            PROTOCOL_SEED,
            DRIP_CUT_BPS
        );
        console.log("CompetitionManager:", address(cm));

        // 6. Deploy BattleManager
        BattleManager bm = new BattleManager(
            address(factory),
            treasury,
            CHALLENGE_FEE,
            BATTLE_PROTOCOL_CUT_BPS,
            MIN_WAGER
        );
        console.log("BattleManager:", address(bm));

        // 7. Deploy GhostRegistry
        GhostRegistry gr = new GhostRegistry(
            treasury,
            PERFORMANCE_FEE_BPS,
            GHOST_PROTOCOL_SHARE_BPS
        );
        console.log("GhostRegistry:", address(gr));

        // 8. Deploy SquadManager
        SquadManager sq = new SquadManager(
            treasury,
            SQUAD_CREATION_FEE,
            BOOST_FEE,
            MAX_MEMBERS,
            BOOST_DURATION
        );
        console.log("SquadManager:", address(sq));

        vm.stopBroadcast();

        // Print summary
        console.log("");
        console.log("=== DEPLOYMENT SUMMARY ===");
        console.log("DripPool:           ", address(pool));
        console.log("DripToken impl:     ", address(tokenImpl));
        console.log("DripVault impl:     ", address(vaultImpl));
        console.log("VaultFactory:       ", address(factory));
        console.log("CompetitionManager: ", address(cm));
        console.log("BattleManager:      ", address(bm));
        console.log("GhostRegistry:      ", address(gr));
        console.log("SquadManager:       ", address(sq));
        console.log("========================");
    }
}
