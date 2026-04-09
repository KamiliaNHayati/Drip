# 💧 Drip — Social Yield Protocol on Initia

> **Automated yield compounding, PvP yield battles, and ghost operators — all on Initia evm-1.**

## Initia Hackathon Submission

- **Project Name**: Drip

### Project Overview

Drip is a social yield protocol on Initia where users deposit INIT into managed vaults, earn yield through DripPool lending, and compete in PvP yield battles. Ghost operators auto-compound yield 24/7 using Initia's native auto-signing feature, eliminating gas friction for depositors. Drip turns passive yield farming into an active, competitive, and social experience — built for DeFi users who want hands-off compounding with the option to compete.

### Implementation Detail

- **The Custom Implementation**: Drip implements a full DeFi stack of 8 smart contracts: EIP-1167 vault factory, built-in lending pool (DripPool) as the yield source, a trustless ghost operator registry for automated compounding, 1v1 PvP yield battles with INIT wagers, multi-vault yield competitions, and social squads. The core innovation is the Ghost Operator system — permissionless bots that can ONLY call `compound()` on vaults, earning 0.1% of yield while being cryptographically prevented from withdrawing or stealing funds.
- **The Native Feature**: Drip uses **auto-signing** via Initia's InterwovenKit. When a vault creator delegates a Ghost Operator, the ghost's wallet uses auto-signing to execute `compound()` transactions automatically without manual approval popups. This enables true 24/7 hands-off yield compounding — the ghost harvests DripPool interest and reinvests it into the vault continuously, with zero user interaction required after the initial delegation.

### How to Run Locally

1. Clone the repo and install frontend dependencies:
   ```bash
   git clone https://github.com/KamiliaNHayati/Drip.git
   cd Drip/frontend && npm install
   ```
2. Start the development server:
   ```bash
   npm run dev
   ```
3. Open `http://localhost:3000` and connect your wallet via InterwovenKit (ensure you have testnet INIT from [faucet.initia.tech](https://faucet.initia.tech)).
4. Contracts are already deployed on evm-1 testnet — no local deployment needed.

---

Drip is a DeFi protocol where users deposit INIT into managed vaults, earn yield through DripPool lending, and compete in PvP yield battles. Ghost operators auto-compound yield 24/7 with zero gas fees for depositors.

## 🔗 Links

| | |
|---|---|
| **Live Demo** | https://drip-xi-seven.vercel.app/ |
| **Testnet Explorer** | [Initia Scan (evm-1)](https://scan.testnet.initia.xyz/evm-1/evm-contracts/0x9D8d7DbEccD15438111E0D162caf2BAF1C9B1D61/overview) |
| **Hackathon** | INITIATE: The Initia Hackathon (Season 1) |

## 🏗️ Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  DripVault  │────▶│   DripPool   │────▶│  Borrowers  │
│ (per vault) │     │ (lending pool)│    │ (pay 8% APY)│
└──────┬──────┘     └──────────────┘     └─────────────┘
       │                    │
       ▼                    ▼
┌──────────────┐     ┌──────────────┐
│ GhostRegistry│     │  Yield flows │
│ (operators)  │     │  back to     │
└──────────────┘     │  depositors  │
                     └──────────────┘
```

**8 Smart Contracts** deployed on Initia evm-1 testnet:

| Contract | Role |
|----------|------|
| `VaultFactory` | Creates vault proxies via EIP-1167 clones |
| `DripVault` | Per-vault deposit/withdraw/compound logic |
| `DripToken` | ERC20 receipt token (dripINIT) |
| `DripPool` | Built-in lending pool (yield source) |
| `GhostRegistry` | Trustless ghost operator registry |
| `BattleManager` | 1v1 PvP yield battles with INIT wagers |
| `CompetitionManager` | Multi-vault yield competitions |
| `SquadManager` | Social squads with projected yield boosts |

## ✨ Key Features

### 🏦 Yield Vaults
- Anyone can create a vault (3 INIT fee)
- Deposit INIT → receive dripINIT (receipt token that grows in value)
- Yield comes from DripPool borrower interest (8% APY)
- Creator earns a configurable performance fee (5–20%) from vault yield

### 👻 Ghost Operators
- Register as a ghost operator (free)
- Vault creators delegate compounding to ghosts (5 INIT one-time fee)
- Ghosts call `compound()` automatically — earn 0.1% of yield per compound
- Ghost wallets can ONLY compound — they cannot withdraw or steal funds

### ⚔️ PvP Yield Battles
- Vault creators challenge rival vaults to 1v1 yield wars
- Both sides stake INIT as wager (min 10 INIT)
- Winner (highest PPS growth) takes 80% of combined pot
- Protocol takes 20%; challenger wins tiebreaker

### 🤝 Social Squads
- Team up in squads of up to 10 wallets (10 INIT creation fee)
- With ≥ 2 members, activate a 24-hour projected yield boost for 1 INIT
- **Note:** Squad boosts are a UI projection in V1. On-chain yield multipliers are planned for V2.

### 🏦 DripPool Lending
- Depositors' INIT becomes lending capital
- Borrowers add collateral and borrow INIT at 8% APY
- Interest flows back as yield to vault depositors

### 🛡️ Safety Features
- Initia Connect oracle integration for price monitoring
- Defensive mode: vault pauses compounding after 3 consecutive price drops
- ReentrancyGuard on all state-changing functions
- SafeERC20 for all token transfers
- Emergency mode in DripPool (halts deposits/borrows, always allows withdrawals)
- Dead shares protection against ERC4626 inflation attacks

## 🔧 Initia-Native Features Used

| Feature | Implementation |
|---------|---------------|
| **InterwovenKit** | Wallet connection via `@initia/interwovenkit-react` with Privy social login |
| **EVM Rollup (evm-1)** | All 8 contracts deployed on evm-1 testnet |
| **Connect Oracle** | Enshrined price feed for defensive mode guard |
| **wagmi + viem** | EVM-native transaction signing for all contract interactions |

## 🚀 Getting Started

### Prerequisites
- Node.js 18+
- Foundry (for contracts)
- Wallet with testnet INIT ([faucet](https://faucet.initia.tech))

### Frontend
```bash
cd frontend
npm install
npm run dev
# Open http://localhost:3000
```

### Contracts
```bash
cd contracts
forge install
forge test
forge script script/DeployAll.s.sol --broadcast --rpc-url $RPC_URL
# Then seed the lending pool:
forge script script/Seed.s.sol --broadcast --rpc-url $RPC_URL
```

## 📍 Deployed Contracts (evm-1 Testnet)

Chain ID: `2124225178762456` · RPC: `https://jsonrpc-evm-1.anvil.asia-southeast.initia.xyz`

| Contract | Address |
|----------|---------|
| DripPool | `0x2E97f225dcC77780bB62059668144F64dfF5eF04` |
| DripToken (impl) | `0xC5404DFF75F7aFc6C2d6c53c39B1965FD86A6B58` |
| DripVault (impl) | `0x31fAa0FAFCbF2cEa1CE89DD28f2b71d94dB442aC` |
| VaultFactory | `0x9D8d7DbEccD15438111E0D162caf2BAF1C9B1D61` |
| CompetitionManager | `0x519Bd4777f72d41dE47FD1490E099f12b46A2Cb5` |
| BattleManager | `0xa44C796f39955daDbA335f990E44cACa412D596C` |
| GhostRegistry | `0xdfCC740D3dD3a48802692B903a93f76A3774b1CA` |
| SquadManager | `0x1680E051941DbD2BFBD7d310CBe1042e1FD8De25` |
| Connect Oracle (precompile) | `0x031ECb63480983FD216D17BB6e1d393f3816b72F` |
| INIT ERC20 (evm-1) | `0x2eE7007DF876084d4C74685e90bB7f4cd7c86e22` |

> DripVault and DripToken are deployed per-vault via VaultFactory as EIP-1167 minimal proxies.

## ⚠️ Known Limitations (Honest Disclosure)

These are intentional trade-offs for hackathon scope:

1. **Single-asset lending:** DripPool uses INIT as both collateral and borrowed asset. In production, collateral would be different assets (ETH, USDC) with Connect oracle price feeds for proper LTV enforcement. For the demo, the admin seeds a borrow position to generate visible yield.

2. **Squad boosts are UI-only:** The projected APY boost display in the frontend is a UI projection. Actual on-chain yield is not modified in V1. On-chain multipliers are planned for V2.

3. **Ghost compound frequency:** Ghost operators call `compound()` via scripts or manual triggers in the demo. Production would use an always-on keeper bot SDK.

4. **Testnet only:** All contracts are on Initia testnet. Testnet INIT has no monetary value. Do not deploy to mainnet without a full security audit.

## 🗺️ Roadmap (Post-Hackathon V2)

- [ ] Multi-asset collateral with Connect oracle price feeds
- [ ] Flash loans in DripPool
- [ ] On-chain squad yield multipliers
- [ ] MilkyWay liquid staking integration
- [ ] Echelon lending integration
- [ ] Cross-rollup vault strategies via IBC
- [ ] Automated ghost keeper bot SDK
- [ ] Governance token and DAO treasury
- [ ] `.init` username integration for vault names

## 🧪 Testing

```bash
cd contracts
forge test -v
```

Test coverage spans all 8 contracts including DripPool, DripVault, DripToken, VaultFactory, BattleManager, CompetitionManager, GhostRegistry, and SquadManager.

## 📁 Project Structure

```
├── contracts/          # Solidity smart contracts (Foundry)
│   ├── src/           # Contract source files
│   ├── test/          # Test files (one per contract)
│   └── script/        # DeployAll.s.sol + Seed.s.sol
├── frontend/          # Next.js 16 frontend
│   ├── src/app/       # App router pages
│   ├── src/components/# React components
│   └── src/lib/       # Contract ABIs & deployed addresses
└── design/            # Design assets
```

## 👥 Team

Built for **INITIATE: The Initia Hackathon (Season 1)**

## 📄 License

MIT
