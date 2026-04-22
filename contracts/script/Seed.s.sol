// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DripPool} from "../src/DripPool.sol";
import {DripVault} from "../src/DripVault.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {CompetitionManager} from "../src/CompetitionManager.sol";

/// @title Seed Drip Protocol on Testnet
/// @notice Seeds pool liquidity, creates borrow position, funds CompetitionManager, creates first vault
/// @dev Run: forge script script/Seed.s.sol --rpc-url $RPC --account Initia1 --broadcast --via-ir
///      IMPORTANT: Update the addresses below after running DeployAll.s.sol!
contract Seed is Script {
    // ─── UPDATE THESE AFTER DEPLOYMENT ─────────────────────────────────
    address constant POOL = 0xBAFdF0273644d4f80A9f77718346Dc706Bbb36e6;          // <-- UPDATE
    address constant FACTORY = 0x1EbCF4ff378274DEA425f37670F787AEBdb7d0d0;       // <-- UPDATE
    address constant COMPETITION = 0xE92e218c2c0B186dB54E31867BC70bd1decBF472;   // <-- UPDATE

    address constant INIT_TOKEN = 0x042adD9e80f7a23Ab71D5e1d392af1d3928B7D05;

    function run() external {
        require(POOL != address(0), "Update POOL address first!");
        require(FACTORY != address(0), "Update FACTORY address first!");
        require(COMPETITION != address(0), "Update COMPETITION address first!");

        IERC20 initToken = IERC20(INIT_TOKEN);
        DripPool pool = DripPool(POOL);
        VaultFactory factory = VaultFactory(FACTORY);

        address deployer = msg.sender;
        console.log("Seeder:", deployer);
        console.log("INIT balance:", initToken.balanceOf(deployer));
        console.log("Native balance:", deployer.balance);

        vm.startBroadcast();

        // Step 1: Approve pool to spend INIT
        initToken.approve(POOL, type(uint256).max);
        console.log("Approved pool");

        // Step 2: Supply 100 INIT to pool (initial liquidity)
        pool.supply(100 ether);
        console.log("Supplied 100 INIT to pool");

        // Step 3: Add 150 INIT collateral
        pool.addCollateral(150 ether);
        console.log("Added 150 INIT collateral");

        // Step 4: Borrow 80 INIT (~80% utilization)
        pool.borrow(80 ether);
        console.log("Borrowed 80 INIT");

        // Step 5: Create a test vault (costs 3 INIT native)
        (address vault, address token) = factory.createVault{value: 3 ether}(
            "Genesis", "The first Drip vault", 1000
        );
        console.log("Created vault:", vault);
        console.log("Created token:", token);

        // Step 6: Deposit 50 INIT into the vault
        initToken.approve(vault, type(uint256).max);
        DripVault(vault).deposit(50 ether);
        console.log("Deposited 50 INIT into vault");

        vm.stopBroadcast();

        // Verify
        console.log("");
        console.log("=== SEED SUMMARY ===");
        console.log("Pool utilization:", pool.utilizationRate());
        console.log("Pool totalDeposits:", pool.totalDeposits());
        console.log("Pool totalBorrowed:", pool.totalBorrowed());
        console.log("Vault address:", vault);
        console.log("Token address:", token);
        console.log("====================");
    }
}
