'use client';

import { useState, useEffect } from 'react';

const sections = [
  { id: 'intro',        label: 'What is Drip?' },
  { id: 'how-it-works', label: 'How It Works' },
  { id: 'vaults',       label: 'Vaults & Depositing' },
  { id: 'drippool',     label: 'DripPool (Yield Source)' },
  { id: 'autosign',     label: 'AutoSign & Ghost Wallets' },
  { id: 'oracle',       label: 'Connect Oracle' },
  { id: 'competitions', label: 'Yield Competitions' },
  { id: 'battles',      label: 'PvP Battles' },
  { id: 'ghosts',       label: 'Ghost Operators' },
  { id: 'squads',       label: 'Social Squads' },
  { id: 'fees',         label: 'Fees & Revenue' },
  { id: 'security',     label: 'Security' },
  { id: 'contracts',    label: 'Contract Addresses' },
  { id: 'limitations',  label: 'Hackathon Limitations' },
];

export default function DocsPage() {
  const [active, setActive] = useState('intro');

  // Simple scroll spy to update active tab
  useEffect(() => {
    const handleScroll = () => {
      const pageYOffset = window.scrollY;
      let newActiveSection = sections[0].id;

      sections.forEach((section) => {
        const element = document.getElementById(section.id);
        if (element && pageYOffset >= element.offsetTop - 150) {
          newActiveSection = section.id;
        }
      });
      setActive(newActiveSection);
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const Divider = () => (
    <div className="w-full h-px bg-gradient-to-r from-transparent via-white/10 to-transparent my-16" />
  );

  return (
    <main className="min-h-screen bg-gradient-to-b from-[#0d0520] via-[#080312] to-[#050505] pt-12 pb-32 relative text-zinc-300 selection:bg-blue-500/30">
      
      {/* Ambient Purple Glow */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full max-w-4xl h-64 bg-gradient-to-b from-purple-500/12 via-fuchsia-500/5 to-transparent blur-[100px] pointer-events-none" />
      <div className="absolute bottom-0 right-0 w-[400px] h-[300px] bg-fuchsia-700/8 rounded-full blur-[120px] pointer-events-none" />

      <div className="max-w-7xl mx-auto px-6 relative z-10">
        
        {/* Page Header */}
        <div className="mb-16">
          <h1 className="text-4xl md:text-5xl font-serif font-medium text-white tracking-tight mb-4">
            Protocol Documentation
          </h1>
          <p className="text-lg text-zinc-400 max-w-2xl">
            Everything you need to know about Drip's architecture, yield mechanics, and social features.
          </p>
        </div>

        <div className="flex flex-col lg:flex-row gap-12 items-start">

          {/* ── Sidebar (Sticky on Desktop) ── */}
          <aside className="hidden lg:block w-64 shrink-0 sticky top-32">
            <div className="bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-3xl p-6 shadow-2xl max-h-[calc(100vh-10rem)] overflow-y-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
              <h3 className="text-xs font-bold text-zinc-500 uppercase tracking-widest mb-4">Contents</h3>
              <ul className="flex flex-col gap-1.5">
                {sections.map(s => (
                  <li key={s.id}>
                    <a
                      href={`#${s.id}`}
                      onClick={() => setActive(s.id)}
                      className={`block px-3 py-2 rounded-xl text-sm font-medium transition-all duration-200 ${
                        active === s.id 
                          ? 'bg-white/10 text-white shadow-sm' 
                          : 'text-zinc-500 hover:text-zinc-300 hover:bg-white/5'
                      }`}
                    >
                      {s.label}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          </aside>

          {/* ── Main Content ── */}
          <div className="flex-1 max-w-3xl">

            {/* ── What is Drip ── */}
            <section id="intro" className="scroll-mt-32">
              <h2 className="text-3xl font-serif font-medium text-white mb-6">What is Drip?</h2>
              <p className="leading-relaxed mb-6">
                Drip is a <strong className="text-white">social yield vault protocol</strong> built natively on Initia.
                Users deposit INIT, earn auto-compounded lending yield, and compete with their
                community through yield competitions and 1v1 vault battles — all powered by
                Initia's native AutoSign and Connect oracle primitives.
              </p>
              <div className="bg-blue-500/10 border-l-4 border-blue-500 p-5 rounded-r-xl mb-6 text-sm">
                <strong className="text-blue-400">Core idea:</strong> yield farming is usually anonymous and solo.
                Drip makes it social, competitive, and automatic.
              </div>
              <p className="leading-relaxed">
                Drip is deployed as its own EVM rollup (drip-1) on the Initia ecosystem.
                All contracts are on-chain. No custodians, no keeper bots, no off-chain infrastructure required.
              </p>
            </section>

            <Divider />

            {/* ── How It Works ── */}
            <section id="how-it-works" className="scroll-mt-32">
              <h2 className="text-3xl font-serif font-medium text-white mb-8">How It Works</h2>
              
              <div className="flex flex-col gap-6 mt-8">
                {[
                  { num: '1', title: 'Deposit INIT', desc: 'Deposit INIT tokens into any vault. The vault deploys your capital into DripPool (a lending pool) where it earns interest from borrowers. You receive dripINIT receipt tokens representing your share.' },
                  { num: '2', title: 'Auto-compound', desc: 'Enable AutoSign once. A ghost wallet (your own Privy embedded wallet) calls compound() on your behalf — harvesting lending yield and re-depositing it. No manual claiming, no keeper bots.' },
                  { num: '3', title: 'Compete & Earn', desc: 'Enter yield competitions or challenge rival vaults to 1v1 battles. Winner is determined by Price-Per-Share growth — whoever\'s vault compounded best wins the prize pool.' }
                ].map((step) => (
                  <div key={step.num} className="flex gap-5">
                    <div className="shrink-0 w-10 h-10 rounded-full bg-white/5 border border-white/10 flex items-center justify-center font-mono font-bold text-white shadow-sm">
                      {step.num}
                    </div>
                    <div className="flex flex-col gap-1 pt-1.5">
                      <h4 className="text-lg font-serif font-medium text-white">{step.title}</h4>
                      <p className="leading-relaxed text-sm text-zinc-400">{step.desc}</p>
                    </div>
                  </div>
                ))}
              </div>
            </section>

            <Divider />

            {/* ── Vaults ── */}
            <section id="vaults" className="scroll-mt-32">
              <h2 className="text-3xl font-serif font-medium text-white mb-6">Vaults & Depositing</h2>
              <p className="leading-relaxed mb-6">
                A Vault is a cloned smart contract created by a <strong className="text-white">vault creator</strong>.
                Each vault has a unique name, description, and creator performance fee (5–20%). Anyone can deposit into any vault.
              </p>

              <h4 className="text-xl font-serif text-white mb-3 mt-8">Creating a vault</h4>
              <p className="leading-relaxed text-sm mb-6 text-zinc-400">
                Any wallet can create a vault for <strong className="text-white">free</strong> (zero creation fee). The creator sets
                their performance fee — a percentage of yield earned by all depositors in their
                vault. This fee is auto-distributed to the creator each compound cycle.
                Drip Protocol takes 10% of the creator's earnings.
              </p>

              <h4 className="text-xl font-serif text-white mb-3 mt-8">Receipt tokens (dripINIT)</h4>
              <p className="leading-relaxed text-sm mb-6 text-zinc-400">
                When you deposit, you receive <code className="bg-white/10 text-white font-mono text-xs px-1.5 py-0.5 rounded">dripINIT</code> — a standard ERC20 token
                representing your proportional share of the vault. As yield compounds, each
                <code className="bg-white/10 text-white font-mono text-xs px-1.5 py-0.5 rounded ml-1">dripINIT</code> becomes redeemable for more INIT. The token is fully
                transferable: if you send it to someone else, they inherit your vault position.
              </p>

              <div className="bg-purple-500/10 border-l-4 border-purple-500 p-5 rounded-r-xl my-8 text-sm">
                <strong className="text-purple-400">Delta Skim model:</strong> the vault tracks its last known asset value.
                On each <code className="font-mono opacity-80">compound()</code>, it harvests only the <em>growth</em> since last
                compound — avoiding double-counting and keeping accounting consistent.
              </div>

              <h4 className="text-xl font-serif text-white mb-3 mt-8">Depositing step by step</h4>
              <ol className="list-decimal list-inside space-y-2 text-sm text-zinc-400 mb-8">
                <li>Approve the INIT ERC20 token for the vault contract (one-time per vault)</li>
                <li>Call <code className="bg-white/10 text-white font-mono px-1.5 py-0.5 rounded">deposit(amount)</code> — vault deploys INIT into DripPool</li>
                <li>Receive <code className="bg-white/10 text-white font-mono px-1.5 py-0.5 rounded">dripINIT</code> shares proportional to your deposit</li>
                <li>Enable AutoSign to allow the ghost wallet to compound automatically</li>
                <li>Withdraw anytime by burning your <code className="bg-white/10 text-white font-mono px-1.5 py-0.5 rounded">dripINIT</code> shares</li>
              </ol>

              <h4 className="text-xl font-serif text-white mb-3 mt-8">Defensive mode</h4>
              <p className="leading-relaxed text-sm text-zinc-400">
                Each vault reads the Connect oracle before compounding. If the INIT price
                drops 3 consecutive compound cycles (configurable by the creator), the vault
                enters <strong className="text-white">defensive mode</strong> and pauses compounding until the price
                recovers to 102% of the last recorded drop price. This protects depositors from
                compounding into a falling market.
              </p>
            </section>

            <Divider />

            {/* ── DripPool ── */}
            <section id="drippool" className="scroll-mt-32">
              <h2 className="text-3xl font-serif font-medium text-white mb-6">DripPool — The Yield Source</h2>
              <p className="leading-relaxed mb-8">
                DripPool is Drip's built-in lending pool deployed on the same Minitia.
                It is the single source of yield for all vaults.
              </p>

              <h4 className="text-xl font-serif text-white mb-3">How lending works</h4>
              <p className="leading-relaxed text-sm text-zinc-400 mb-6">
                Lenders supply INIT and receive pool shares. Their shares appreciate as
                borrowers pay interest. Borrowers post INIT as collateral and borrow INIT
                at a fixed 8% APY. Interest is split: 90% goes to lenders (via rising
                share price), 10% goes to the Drip protocol treasury (reserve factor).
              </p>

              <div className="bg-black/40 border border-white/10 rounded-2xl overflow-hidden mb-8">
                <table className="w-full text-left text-sm">
                  <thead className="bg-white/5 border-b border-white/10">
                    <tr>
                      <th className="px-6 py-4 font-bold text-zinc-500 uppercase tracking-widest text-[10px]">Parameter</th>
                      <th className="px-6 py-4 font-bold text-zinc-500 uppercase tracking-widest text-[10px]">Value</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/5">
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Borrow APY</td><td className="px-6 py-4 text-zinc-400">8% (fixed)</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Reserve factor</td><td className="px-6 py-4 text-zinc-400">10% of interest → treasury</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Collateral factor</td><td className="px-6 py-4 text-zinc-400">75% LTV max</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Liquidation penalty</td><td className="px-6 py-4 text-zinc-400">10% (5% to protocol, 5% to liquidator)</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Min first deposit</td><td className="px-6 py-4 text-zinc-400">&gt; 1000 wei (dead shares protection)</td></tr>
                  </tbody>
                </table>
              </div>

              <h4 className="text-xl font-serif text-white mb-3">Security mechanisms</h4>
              <ul className="list-disc list-outside ml-5 space-y-2 text-sm text-zinc-400">
                <li><strong className="text-white">Dead shares:</strong> 1000 shares burned to address(0) on first deposit — prevents the classic ERC4626 inflation attack</li>
                <li><strong className="text-white">Emergency mode:</strong> admin can halt new deposits and borrows while allowing withdrawals</li>
                <li><strong className="text-white">BorrowIndex:</strong> individual debt compounds correctly using a global interest index, same model as Aave/Compound</li>
              </ul>
            </section>

            <Divider />

            {/* ── AutoSign ── */}
            <section id="autosign" className="scroll-mt-32">
              <h2 className="text-3xl font-serif font-medium text-white mb-6">AutoSign & Ghost Wallets</h2>
              <p className="leading-relaxed mb-6">
                Initia's <strong className="text-white">AutoSign</strong> is a native protocol feature that lets users
                delegate specific on-chain actions to an embedded wallet — without sharing
                private keys or trusting a third party.
              </p>

              <h4 className="text-xl font-serif text-white mb-3">How AutoSign works</h4>
              <ol className="list-decimal list-outside ml-5 space-y-2 text-sm text-zinc-400 mb-8">
                <li>You connect your main wallet (Keplr, Leap, or social login via Privy)</li>
                <li>You enable AutoSign for your vault — this signs one transaction granting
                  a <em>ghost wallet</em> (your own Privy embedded wallet) permission to call
                  <code className="bg-white/10 text-white font-mono px-1.5 py-0.5 rounded ml-1">compound()</code> on your behalf</li>
                <li>The ghost wallet holds no funds — it only has <code className="bg-white/10 text-white font-mono px-1.5 py-0.5 rounded">authz</code> permission
                  to execute one specific function</li>
                <li>Permissions are time-limited and revocable anytime from your wallet settings</li>
              </ol>

              

              <div className="bg-blue-500/10 border-l-4 border-blue-500 p-5 rounded-r-xl my-8 text-sm">
                <strong className="text-blue-400">Not a keeper bot.</strong> The ghost wallet is <em>your own</em> embedded
                wallet — no third party can use it. This is architecturally impossible, not just
                a promise.
              </div>

              <h4 className="text-xl font-serif text-white mb-3">Ghost operator delegation (optional)</h4>
              <p className="leading-relaxed text-sm text-zinc-400">
                Vault creators can optionally delegate their vault's compounding to a registered
                Ghost Operator — a third party who runs their own compounding bot. The creator
                pays a one-time 5 INIT delegation fee. The ghost operator earns 0.1% of yield
                per compound cycle from the creator's fee share.
              </p>
            </section>

            <Divider />

            {/* ── Oracle ── */}
            <section id="oracle" className="scroll-mt-32">
              <h2 className="text-3xl font-serif font-medium text-white mb-6">Connect Oracle</h2>
              <p className="leading-relaxed mb-6">
                Drip uses Initia's <strong className="text-white">Connect oracle</strong> — an <em>enshrined</em> price
                feed built directly into the Initia consensus layer. Validators submit price data
                as part of the block proposal process.
              </p>
              <ul className="list-disc list-outside ml-5 space-y-2 text-sm text-zinc-400 mb-6">
                <li>Prices cannot be censored or delayed by chain congestion</li>
                <li>No external oracle dependency (no Chainlink, no Pyth)</li>
                <li>Price data is validated by the same validators securing the chain</li>
                <li>Drip reads <code className="bg-white/10 text-white font-mono px-1.5 py-0.5 rounded">INIT/USD</code> price before every compound cycle</li>
                <li>Staleness check: if price timestamp is older than 60 seconds, compounding is skipped gracefully</li>
              </ul>
              <p className="leading-relaxed text-sm text-zinc-400">
                The oracle is accessed via a precompile at
                <code className="bg-white/10 text-white font-mono px-1.5 py-0.5 rounded ml-1">0x031ECb63480983FD216D17BB6e1d393f3816b72F</code> on the drip-1 rollup.
              </p>
            </section>

            <Divider />

            {/* ── Competitions ── */}
            <section id="competitions" className="scroll-mt-32">
              <h2 className="text-3xl font-serif font-medium text-white mb-6">Yield Competitions</h2>
              <p className="leading-relaxed mb-6">
                Any active vault (with ≥ 2 depositors) can host a yield competition.
                Participants enter individually and are ranked by their vault's
                <strong className="text-white"> Price-Per-Share (PPS)</strong> growth during the epoch.
              </p>

              <h4 className="text-xl font-serif text-white mb-3">PPS growth formula</h4>
              <div className="bg-black/60 border border-white/10 rounded-xl p-5 font-mono text-sm text-blue-300 leading-loose mb-6 overflow-x-auto whitespace-nowrap">
                startPPS = vault.totalAssets × 1e18 / dripToken.totalSupply<br/>
                currentPPS = vault.totalAssets × 1e18 / dripToken.totalSupply<br/>
                growthBps = (currentPPS − startPPS) × 10000 / startPPS
              </div>
              <p className="leading-relaxed text-sm text-zinc-400 mb-8">
                Using PPS instead of user balance prevents the <em>phantom deposit exploit</em>:
                a participant cannot withdraw their stake mid-competition and still claim victory.
                The vault's performance is measured independently of any individual's balance.
              </p>

              <h4 className="text-xl font-serif text-white mb-3">Competition lifecycle</h4>
              <ol className="list-decimal list-outside ml-5 space-y-2 text-sm text-zinc-400 mb-8">
                <li>Creator calls <code className="bg-white/10 text-white font-mono px-1.5 py-0.5 rounded">createCompetition(vault, duration)</code> — protocol seeds 23 INIT into the prize pool</li>
                <li>Participants enter by paying 7 INIT — added to prize pool</li>
                <li>At epoch end, anyone calls <code className="bg-white/10 text-white font-mono px-1.5 py-0.5 rounded">settleCompetition()</code></li>
                <li>Winner (highest PPS growth) receives 90% of prize pool</li>
                <li>Protocol keeps 10% of prize pool</li>
                <li>If all participants have 0% growth: 95% of entry fees refunded, protocol keeps 5% + seed</li>
              </ol>

              <div className="bg-black/40 border border-white/10 rounded-2xl overflow-hidden mb-8">
                <table className="w-full text-left text-sm">
                  <thead className="bg-white/5 border-b border-white/10">
                    <tr>
                      <th className="px-6 py-4 font-bold text-zinc-500 uppercase tracking-widest text-[10px]">Parameter</th>
                      <th className="px-6 py-4 font-bold text-zinc-500 uppercase tracking-widest text-[10px]">Value</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/5">
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Entry fee</td><td className="px-6 py-4 text-zinc-400">7 INIT (~$0.56)</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Protocol seed</td><td className="px-6 py-4 text-zinc-400">23 INIT per competition</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Protocol cut</td><td className="px-6 py-4 text-zinc-400">10% of prize pool</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Min depositors to create</td><td className="px-6 py-4 text-zinc-400">2</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Max participants</td><td className="px-6 py-4 text-zinc-400">100</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Duration range</td><td className="px-6 py-4 text-zinc-400">1 hour – 30 days</td></tr>
                  </tbody>
                </table>
              </div>
            </section>

            <Divider />

            {/* ── Battles ── */}
            <section id="battles" className="scroll-mt-32">
              <h2 className="text-3xl font-serif font-medium text-white mb-6">PvP Yield Battles</h2>
              <p className="leading-relaxed mb-6">
                Any vault creator can challenge another vault to a 1v1 yield battle.
                Both creators stake INIT as a wager. The vault with higher PPS growth
                during the battle epoch wins the combined stakes.
              </p>

              <h4 className="text-xl font-serif text-white mb-3">Battle lifecycle</h4>
              <ol className="list-decimal list-outside ml-5 space-y-2 text-sm text-zinc-400 mb-8">
                <li>Challenger pays 40 INIT challenge fee (non-refundable) + wager amount (≥ 10 INIT)</li>
                <li>Defender has 24 hours to accept by matching the wager</li>
                <li>If defender doesn't accept within 24 hours: challenger can cancel and recover their wager (fee stays with protocol)</li>
                <li>Battle runs for the declared duration (1 hour – 7 days)</li>
                <li>At end, anyone settles: higher PPS growth wins 80% of combined stakes</li>
                <li>Protocol takes 20% of combined stakes</li>
                <li>Tiebreaker: challenger wins</li>
              </ol>

              <div className="bg-purple-500/10 border-l-4 border-purple-500 p-5 rounded-r-xl my-6 text-sm">
                <strong className="text-purple-400">One active battle per vault.</strong> A vault cannot be in two battles
                simultaneously. You must settle the current battle before declaring a new one.
              </div>
            </section>

            <Divider />

            {/* ── Ghosts ── */}
            <section id="ghosts" className="scroll-mt-32">
              <h2 className="text-3xl font-serif font-medium text-white mb-6">Ghost Operators</h2>
              <p className="leading-relaxed mb-6">
                Ghost Operators are independent addresses that vault creators can authorize to
                run automated compounding bots. They earn a performance fee for every successful
                compound they execute.
              </p>

              <h4 className="text-xl font-serif text-white mb-3">How to become a Ghost Operator</h4>
              <ol className="list-decimal list-outside ml-5 space-y-2 text-sm text-zinc-400 mb-8">
                <li>Call <code className="bg-white/10 text-white font-mono px-1.5 py-0.5 rounded">registerAsGhost()</code> on GhostRegistry — free, no stake required</li>
                <li>Set up an automated bot that calls <code className="bg-white/10 text-white font-mono px-1.5 py-0.5 rounded">compound()</code> on vaults that delegated to you</li>
                <li>Earn 0.1% of yield per compound (taken from the vault creator's fee share, not depositors)</li>
                <li>Your reliability score is tracked on-chain: <code className="bg-white/10 text-white font-mono px-1.5 py-0.5 rounded">successfulCompounds / totalAttempts × 10000</code></li>
              </ol>

              <h4 className="text-xl font-serif text-white mb-3">How vault creators delegate</h4>
              <p className="leading-relaxed text-sm text-zinc-400 mb-6">
                Creators call <code className="bg-white/10 text-white font-mono px-1.5 py-0.5 rounded">setDelegatedGhost(ghostAddress, registryAddress)</code>
                with a 5 INIT delegation fee. The ghost earns 90% of the performance fee,
                protocol earns 10%. Creators can undelegate instantly at any time.
              </p>

              <div className="bg-black/40 border border-white/10 rounded-2xl overflow-hidden mb-8">
                <table className="w-full text-left text-sm">
                  <thead className="bg-white/5 border-b border-white/10">
                    <tr>
                      <th className="px-6 py-4 font-bold text-zinc-500 uppercase tracking-widest text-[10px]">Metric</th>
                      <th className="px-6 py-4 font-bold text-zinc-500 uppercase tracking-widest text-[10px]">Description</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/5">
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Reliability score</td><td className="px-6 py-4 text-zinc-400">Successful compounds / total attempts (bps)</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Total yield managed</td><td className="px-6 py-4 text-zinc-400">Cumulative INIT yield harvested across all vaults</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Performance fee</td><td className="px-6 py-4 text-zinc-400">0.1% of yield per compound</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Delegation fee</td><td className="px-6 py-4 text-zinc-400">5 INIT (one-time, to treasury)</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Leaderboard size</td><td className="px-6 py-4 text-zinc-400">Top 100 ghosts tracked on-chain</td></tr>
                  </tbody>
                </table>
              </div>

              <h4 className="text-xl font-serif text-white mb-3">🤖 Run Your Own Ghost Bot</h4>
              <p className="leading-relaxed text-sm text-zinc-400 mb-4">
                Drip is fully decentralized — <strong className="text-white">anyone</strong> can run a ghost bot. 
                You don&apos;t need permission from the protocol. Just register your wallet, get delegated by a vault creator, 
                and run a simple script that calls <code className="bg-white/10 text-white font-mono px-1.5 py-0.5 rounded">compound()</code> periodically.
                You earn 0.1% of every yield you harvest.
              </p>

              <div className="bg-black/60 border border-emerald-500/20 rounded-2xl p-6 mb-6">
                <div className="flex items-center gap-2 mb-4">
                  <span className="text-emerald-400 text-sm font-bold">Example: Minimal Ghost Bot (Node.js)</span>
                </div>
                <pre className="text-xs text-zinc-300 font-mono overflow-x-auto leading-relaxed whitespace-pre-wrap">
{`import { createWalletClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';

const VAULT_ADDRESS = '0xYourDelegatedVault';
const account = privateKeyToAccount('0xYourPrivateKey');

const client = createWalletClient({
  account,
  transport: http('http://localhost:8545'),
});

// Call compound() every hour
setInterval(async () => {
  try {
    await client.writeContract({
      address: VAULT_ADDRESS,
      abi: [{ name: 'compound', type: 'function', inputs: [], outputs: [] }],
      functionName: 'compound',
    });
    console.log('✅ Compounded!');
  } catch (e) {
    console.log('⏭️  No yield to compound');
  }
}, 60 * 60 * 1000); // every 1 hour`}
                </pre>
              </div>

              <div className="bg-emerald-500/5 border border-emerald-500/20 rounded-xl p-4 mb-8">
                <p className="text-sm text-emerald-300 font-medium mb-2">🔒 Security Guarantee</p>
                <p className="text-sm text-zinc-400">
                  Ghost wallets can <strong className="text-white">only call compound()</strong>. They cannot withdraw, 
                  transfer, or access any depositor funds. The smart contract enforces this at the bytecode level — 
                  even a compromised ghost cannot steal anything.
                </p>
              </div>
            </section>

            <Divider />

            {/* ── Squads ── */}
            <section id="squads" className="scroll-mt-32">
              <h2 className="text-3xl font-serif font-medium text-white mb-6">Social Squads</h2>
              <p className="leading-relaxed mb-6">
                Squads are named groups of up to 10 wallets. When 2 or more squad members
                are deposited together, the squad can activate a <strong className="text-white">yield boost</strong>
                — a projected APY multiplier displayed in the UI.
              </p>

              <div className="bg-blue-500/10 border-l-4 border-blue-500 p-5 rounded-r-xl my-6 text-sm">
                <strong className="text-blue-400">MVP note:</strong> the boost is a UI projection only. The on-chain
                yield calculation is unchanged in the current version. Actual on-chain yield
                multipliers will be implemented in V2.
              </div>

              <h4 className="text-xl font-serif text-white mb-3 mt-8">Squad mechanics</h4>
              <ul className="list-disc list-outside ml-5 space-y-2 text-sm text-zinc-400">
                <li>Create a squad for 10 INIT — choose a unique name (max 32 characters)</li>
                <li>Invite up to 9 other wallets to join (one squad per wallet)</li>
                <li>With ≥ 2 members, activate a 24-hour boost for 1 INIT</li>
                <li>2 members: +5% projected APY display</li>
                <li>3+ members: +10% projected APY display</li>
                <li>Leave a squad at any time</li>
              </ul>
            </section>

            <Divider />

            {/* ── Fees ── */}
            <section id="fees" className="scroll-mt-32">
              <h2 className="text-3xl font-serif font-medium text-white mb-6">Fees & Revenue</h2>
              
              <div className="bg-black/40 border border-white/10 rounded-2xl overflow-hidden mb-4">
                <table className="w-full text-left text-sm">
                  <thead className="bg-white/5 border-b border-white/10">
                    <tr>
                      <th className="px-6 py-4 font-bold text-zinc-500 uppercase tracking-widest text-[10px]">Source</th>
                      <th className="px-6 py-4 font-bold text-zinc-500 uppercase tracking-widest text-[10px]">Amount</th>
                      <th className="px-6 py-4 font-bold text-zinc-500 uppercase tracking-widest text-[10px]">Trigger</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/5">
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">DripPool reserve factor</td><td className="px-6 py-4 text-zinc-400">10% of borrower interest</td><td className="px-6 py-4 text-zinc-400">Continuous</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Liquidation fee</td><td className="px-6 py-4 text-zinc-400">5% of debt</td><td className="px-6 py-4 text-zinc-400">Each liquidation</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Vault creation</td><td className="px-6 py-4 text-zinc-400">Free (0 fee)</td><td className="px-6 py-4 text-zinc-400">Each vault</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Drip cut of creator fee</td><td className="px-6 py-4 text-zinc-400">10% of creator earnings</td><td className="px-6 py-4 text-zinc-400">Each compound</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Competition entry</td><td className="px-6 py-4 text-zinc-400">7 INIT per participant</td><td className="px-6 py-4 text-zinc-400">Each entry</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Competition prize cut</td><td className="px-6 py-4 text-zinc-400">10% of prize pool</td><td className="px-6 py-4 text-zinc-400">Each settlement</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Battle challenge fee</td><td className="px-6 py-4 text-zinc-400">40 INIT</td><td className="px-6 py-4 text-zinc-400">Each challenge</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Battle prize cut</td><td className="px-6 py-4 text-zinc-400">20% of combined stakes</td><td className="px-6 py-4 text-zinc-400">Each settlement</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Ghost delegation</td><td className="px-6 py-4 text-zinc-400">5 INIT</td><td className="px-6 py-4 text-zinc-400">Each delegation</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Squad creation</td><td className="px-6 py-4 text-zinc-400">10 INIT</td><td className="px-6 py-4 text-zinc-400">Each squad</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-medium text-white">Squad boost</td><td className="px-6 py-4 text-zinc-400">1 INIT</td><td className="px-6 py-4 text-zinc-400">Each activation</td></tr>
                  </tbody>
                </table>
              </div>
              <p className="text-zinc-500 text-sm mt-4">
                All fees are in native INIT or INIT ERC20. Current prices are optimized for
                testnet demonstration. Mainnet pricing will target sustainable unit economics
                (vault creation ~25 INIT, competition entry ~50 INIT at $0.08–$0.50/INIT).
              </p>
            </section>

            <Divider />

            {/* ── Security ── */}
            <section id="security" className="scroll-mt-32">
              <h2 className="text-3xl font-serif font-medium text-white mb-6">Security</h2>
              <ul className="list-disc list-outside ml-5 space-y-2 text-sm text-zinc-400 mb-6">
                <li><strong className="text-white">ReentrancyGuard</strong> on all state-changing functions across all contracts</li>
                <li><strong className="text-white">Checks-Effects-Interactions</strong> pattern strictly enforced — state updated before external calls</li>
                <li><strong className="text-white">SafeERC20</strong> for all ERC20 interactions — reverts if transfer returns false</li>
                <li><strong className="text-white">Dead shares</strong> in DripPool — prevents ERC4626 first-depositor inflation attack</li>
                <li><strong className="text-white">Oracle staleness check</strong> — rejects price data older than 60 seconds</li>
                <li><strong className="text-white">Clamp on poolShares</strong> — withdrawal never over-withdraws from pool</li>
                <li><strong className="text-white">OwnableUpgradeable</strong> for clone contracts — owner set in initializer, not constructor</li>
                <li><strong className="text-white">.call instead of .transfer</strong> for all native INIT transfers — prevents gas limit DoS</li>
                <li><strong className="text-white">emergencySync()</strong> — creator can resync poolShares from actual pool balance if drift occurs</li>
                <li><strong className="text-white">Emergency mode</strong> in DripPool — halts deposits/borrows, always allows withdrawals</li>
              </ul>
              <div className="bg-purple-500/10 border-l-4 border-purple-500 p-5 rounded-r-xl my-6 text-sm">
                <strong className="text-purple-400">Warning:</strong> This is an MVP on testnet. A full security audit is required before mainnet deployment. Do not deposit real funds.
              </div>
            </section>

            <Divider />

            {/* ── Contracts ── */}
            <section id="contracts" className="scroll-mt-32">
              <h2 className="text-3xl font-serif font-medium text-white mb-6">Contract Addresses</h2>
              <p className="leading-relaxed mb-6">Deployed on Drip rollup (Chain ID: <code className="font-mono text-white">drip-1</code>)</p>
              
              <div className="bg-black/40 border border-white/10 rounded-2xl overflow-hidden mb-4">
                <table className="w-full text-left text-sm">
                  <thead className="bg-white/5 border-b border-white/10">
                    <tr>
                      <th className="px-6 py-4 font-bold text-zinc-500 uppercase tracking-widest text-[10px]">Contract</th>
                      <th className="px-6 py-4 font-bold text-zinc-500 uppercase tracking-widest text-[10px]">Address</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/5 font-mono text-xs">
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-sans font-medium text-white">DripPool</td><td className="px-6 py-4 text-zinc-300">0xBAFdF0273644d4f80A9f77718346Dc706Bbb36e6</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-sans font-medium text-white">VaultFactory</td><td className="px-6 py-4 text-zinc-300">0x1EbCF4ff378274DEA425f37670F787AEBdb7d0d0</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-sans font-medium text-white">CompetitionManager</td><td className="px-6 py-4 text-zinc-300">0xE92e218c2c0B186dB54E31867BC70bd1decBF472</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-sans font-medium text-white">BattleManager</td><td className="px-6 py-4 text-zinc-300">0x12c0D804b1dbAb9056fa1Ca44E24ad066bEA30a8</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-sans font-medium text-white">GhostRegistry</td><td className="px-6 py-4 text-zinc-300">0xBbb79Dd2ae4A71e5f57E71d650f6AD147C9727a1</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-sans font-medium text-white">SquadManager</td><td className="px-6 py-4 text-zinc-300">0x16427Da31d6dD50663b26D7D9ef339e719d7E9Dd</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-sans font-medium text-white">Connect Oracle</td><td className="px-6 py-4 text-zinc-300">0x031ECb63480983FD216D17BB6e1d393f3816b72F</td></tr>
                    <tr className="hover:bg-white/5 transition-colors"><td className="px-6 py-4 font-sans font-medium text-white">INIT ERC20</td><td className="px-6 py-4 text-zinc-300">0x042adD9e80f7a23Ab71D5e1d392af1d3928B7D05</td></tr>
                  </tbody>
                </table>
              </div>
              <p className="text-zinc-500 text-sm">
                All contracts are deployed on the Drip rollup.
              </p>
            </section>

            <Divider />

            {/* ── Limitations ── */}
            <section id="limitations" className="scroll-mt-32">
              <h2 className="text-3xl font-serif font-medium text-white mb-6">Hackathon Limitations</h2>
              <p className="leading-relaxed mb-6">
                Drip was built for the INITIATE Season 1 hackathon. Some design decisions
                were made to fit the scope and timeline:
              </p>
              <ul className="list-disc list-outside ml-5 space-y-4 text-sm text-zinc-400">
                <li>
                  <strong className="text-white block mb-1">Single-asset pool:</strong> DripPool uses INIT-borrows-INIT to simulate
                  utilization and yield for the demo. The admin seeds a borrow position at deployment.
                  No rational user would borrow INIT with INIT collateral in production — V2 will
                  implement multi-asset collateral with Connect oracle price enforcement.
                </li>
                <li>
                  <strong className="text-white block mb-1">Squad boost is UI-only:</strong> the +5%/+10% projected APY display is
                  a frontend projection. Actual on-chain yield is not modified in V1.
                </li>
                <li>
                  <strong className="text-white block mb-1">No cross-rollup strategies:</strong> vaults are confined to the drip-1
                  rollup. MilkyWay and Echelon integrations are planned post-hackathon.
                </li>
                <li>
                  <strong className="text-white block mb-1">Rollup environment:</strong> the drip-1 rollup runs via Weave CLI.
                  Vault creation is free to reduce friction during the hackathon demo.
                </li>
                <li>
                  <strong className="text-white block mb-1">No audit:</strong> contracts have not been formally audited.
                  Do not deploy to mainnet without a full audit.
                </li>
              </ul>
            </section>

          </div>
        </div>
      </div>
    </main>
  );
}