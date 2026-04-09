'use client';

import { useState, useEffect } from 'react';
import { createPublicClient, http, formatEther } from 'viem';
import ConnectButton from '@/components/ConnectButton';
import VaultCard from '@/components/VaultCard';
import BattleCard from '@/components/BattleCard';
import Link from 'next/link';
import { VaultFactoryABI, VaultFactoryAddress, DripVaultABI } from '@/lib/contracts';

const publicClient = createPublicClient({
  transport: http('https://jsonrpc-evm-1.anvil.asia-southeast.initia.xyz'),
});

type VaultData = {
  address: string;
  name: string;
  creator: string;
  tvl: string;
  tvlNum: number;
  apy: string;
  apyNum: number;
  isNew: boolean;
  created: number;
};

export default function LandingPage() {
  const [sortBy, setSortBy] = useState<'tvl' | 'apy' | 'newest'>('tvl');
  const [vaultData, setVaultData] = useState<VaultData[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchVaults() {
      try {
        const count = await publicClient.readContract({
          address: VaultFactoryAddress as `0x${string}`,
          abi: VaultFactoryABI,
          functionName: 'allVaultsLength',
        });

        const vaults: VaultData[] = [];
        for (let i = 0; i < Number(count); i++) {
          const vaultAddr = await publicClient.readContract({
            address: VaultFactoryAddress as `0x${string}`,
            abi: VaultFactoryABI,
            functionName: 'allVaults',
            args: [BigInt(i)],
          }) as string;

          try {
            const info = await publicClient.readContract({
              address: vaultAddr as `0x${string}`,
              abi: DripVaultABI,
              functionName: 'vaultInfo',
            }) as any;

            const tvlWei = BigInt(info[4] || 0);
            const tvlFormatted = Number(formatEther(tvlWei));
            const feeBps = Number(info[3] || 0);

            vaults.push({
              address: vaultAddr,
              name: info[0] || `Vault ${i}`,
              creator: `${vaultAddr.slice(0, 6)}...${vaultAddr.slice(-4)}`,
              tvl: tvlFormatted < 1 ? '0' : tvlFormatted.toLocaleString('en-US', { maximumFractionDigits: 0 }),
              tvlNum: tvlFormatted,
              apy: (feeBps / 100).toFixed(1),
              apyNum: feeBps / 100,
              isNew: i === Number(count) - 1,
              created: i,
            });
          } catch (err) {
            console.error(`Failed to fetch vault ${i}:`, err);
          }
        }

        setVaultData(vaults);
      } catch (err) {
        console.error('Failed to fetch vaults:', err);
      } finally {
        setLoading(false);
      }
    }
    fetchVaults();
  }, []);

  const sortedVaults = [...vaultData].sort((a, b) => {
    if (sortBy === 'tvl') return b.tvlNum - a.tvlNum;
    if (sortBy === 'apy') return b.apyNum - a.apyNum;
    return b.created - a.created;
  });
  return (
    <main className="bg-[#050505]">
      
      {/* ── 1. Hero Section ──────── */}
      <section className="relative min-h-screen flex items-center overflow-hidden">
        
        {/* Video Background */}
        <div className="absolute inset-0 z-0 bg-[#050505]">
          <video 
            autoPlay 
            loop 
            muted 
            playsInline 
            className="w-full h-full object-cover opacity-40 mix-blend-screen"
          >
            <source src="/liquid-bg.mp4" type="video/mp4" />
          </video>
          <div className="absolute inset-0 bg-gradient-to-b from-transparent via-[#050505]/50 to-[#050505]"></div>
        </div>

        {/* Hero Content */}
        <div className="section-container relative z-10 w-full pt-20">
          <div className="flex flex-col lg:flex-row items-center justify-between gap-12">
            
            {/* Left Side: Typography */}
            <div className="max-w-2xl flex flex-col gap-7">
              <h1 className="text-6xl md:text-7xl lg:text-8xl font-serif font-medium tracking-tight leading-[1.05] text-white drop-shadow-lg">
                Yield, automated.<br />
                <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-purple-500">
                  Battles, elevated.
                </span>
              </h1>

              <p className="text-lg text-zinc-300 leading-relaxed max-w-xl font-sans drop-shadow-md">
                Deploy yield vaults, battle rival strategies, and let ghost operators auto-compound 24/7.
              </p>
            </div>

            {/* Right Side: Floating Action Module */}
            <div className="w-full lg:w-auto flex flex-col gap-6 bg-white/5 backdrop-blur-2xl border border-white/10 rounded-[2.5rem] p-8 shadow-2xl relative shrink-0">
              
              {/* Subtle inner glow for the module */}
              <div className="absolute -top-10 -right-10 w-40 h-40 bg-blue-500/20 blur-3xl rounded-full pointer-events-none"></div>
              
              {/* Stats */}
              <div className="flex gap-8 relative z-10">
                <div className="flex flex-col gap-1">
                  <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Total Value Locked</span>
                  <span className="text-2xl font-mono font-bold text-white">~120.5k <span className="text-sm text-zinc-500 font-medium">INIT</span></span>
                </div>
                
                <div className="w-px bg-white/10 self-stretch my-2"></div>
                
                <div className="flex flex-col gap-1">
                  <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Avg Vault APY</span>
                  <span className="text-2xl font-mono font-bold text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-purple-500">12.4%</span>
                </div>
              </div>

              {/* Buttons */}
              <div className="flex flex-col gap-3 relative z-10 w-full mt-2">
                <div className="w-full [&>div]:w-full [&_button]:w-full">
                  <ConnectButton />
                </div>
                <a href="#vaults" className="w-full py-3.5 rounded-full border border-white/10 bg-white/5 text-sm font-semibold text-zinc-300 text-center transition-all duration-300 hover:bg-white/10 hover:text-white hover:border-white/20 flex items-center justify-center">
                  Explore Vaults ↓
                </a>
              </div>
            </div>

          </div>
        </div>
      </section>

      {/* ── 2. How It Works ── */}
      <section className="bg-gradient-to-b from-[#050505] via-[#160d33] to-[#0d071c] relative z-20 py-24">
        <div className="section-container">
          <div className="max-w-3xl mb-16 mx-auto text-center">
            <h2 className="text-4xl md:text-5xl font-serif font-medium text-white tracking-tight mb-4">The new meta.</h2>
            <p className="text-xl text-zinc-400">Yield farming shouldn&apos;t be a solo, manual grind. We fixed it.</p>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {[
              { icon: '🏦', title: 'Deposit INIT', desc: 'Pool funds into themed vaults earning 8% APY base yield.' },
              { icon: '👻', title: 'Auto-Compound',  desc: 'Ghost wallets harvest your yield 24/7. Zero gas fees for you.' },
              { icon: '⚔️', title: 'Compete & Earn', desc: 'Join yield competitions or declare PvP battles to multiply returns.' },
            ].map((step) => (
              <div key={step.title} className="bg-black/40 border border-white/5 rounded-3xl p-8 flex flex-col items-center text-center gap-4 hover:border-white/10 transition-colors shadow-xl">
                <div className="w-16 h-16 bg-white/5 border border-white/10 rounded-full flex items-center justify-center text-3xl shadow-inner mb-2">{step.icon}</div>
                <h3 className="text-2xl font-serif font-medium text-white tracking-tight">{step.title}</h3>
                <p className="text-zinc-400 leading-relaxed text-sm">{step.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── 3. Live Vaults (Parallax Image) ── */}
      <section id="vaults" className="relative z-20 py-32 bg-[#0a0a0a] bg-[url('/vault-bg.png')] bg-cover bg-center bg-fixed scroll-mt-24">
        <div className="absolute inset-0 bg-black/50"></div>
        <div className="absolute top-0 inset-x-0 h-32 bg-gradient-to-b from-[#0d071c] to-transparent"></div>
        <div className="absolute bottom-0 inset-x-0 h-32 bg-gradient-to-t from-[#110826] to-transparent"></div>
        
        <div className="section-container relative z-10">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-12 gap-4">
            <h2 className="text-4xl md:text-5xl font-serif font-medium text-white tracking-tight">Live Vaults</h2>
            <div className="flex items-center gap-3">
              <div className="flex gap-1 p-1 rounded-xl bg-black/60 backdrop-blur-md border border-white/10">
                {(['tvl', 'apy', 'newest'] as const).map((tab) => (
                  <button
                    key={tab}
                    onClick={() => setSortBy(tab)}
                    className={`px-5 py-2 text-sm font-medium rounded-lg transition-colors ${
                      sortBy === tab
                        ? 'text-white bg-white/10 shadow'
                        : 'text-zinc-400 hover:text-white'
                    }`}
                  >
                    {tab === 'tvl' ? 'TVL' : tab === 'apy' ? 'APY' : 'Newest'}
                  </button>
                ))}
              </div>
              <Link 
                href="/create" 
                className="px-5 py-2.5 rounded-xl bg-white text-black text-sm font-semibold transition-all duration-300 hover:bg-zinc-200 hover:-translate-y-0.5 shadow-[0_4px_20px_rgba(255,255,255,0.15)] flex items-center gap-2"
              >
                <span className="text-lg leading-none">+</span> Create Vault
              </Link>
            </div>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {sortedVaults.map((v) => (
              <VaultCard
                key={v.address}
                address={v.address}
                name={v.name}
                creator={v.creator}
                tvl={v.tvl}
                apy={v.apy}
                isNew={v.isNew}
              />
            ))}
          </div>
        </div>
      </section>

      {/* ── 4. Active Battles ── */}
      <section className="bg-gradient-to-b from-[#110826] via-[#090514] to-[#050505] relative z-20 py-24">
        <div className="section-container">
          <h2 className="text-4xl md:text-5xl font-serif font-medium text-white tracking-tight mb-12">Active Battles</h2>
          <div className="flex gap-6 overflow-x-auto pb-8 [scrollbar-width:none]">
            <div className="min-w-[360px] md:min-w-[400px]">
              <BattleCard 
                id="1" 
                challengerName="Yield Kings" 
                defenderName="Mewtopia" 
                wager="100" 
                endTime="12h 45m" 
              />
            </div>
            <div className="min-w-[360px] md:min-w-[400px]">
              <BattleCard 
                id="2" 
                challengerName="Degen Spartans" 
                defenderName="Initia Whales" 
                wager="500" 
                endTime="2d 14h" 
              />
            </div>
          </div>
        </div>
      </section>

      {/* ── 4.5 Ghost Operators — Decentralized Infrastructure ── */}
      <section className="bg-gradient-to-b from-[#050505] via-[#110524] to-[#050505] relative z-20 py-24">
        <div className="section-container">
          <div className="max-w-3xl mx-auto text-center mb-16">
            <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full border border-purple-500/20 bg-purple-500/10 mb-6">
              <span className="w-2 h-2 rounded-full bg-fuchsia-400 shadow-[0_0_8px_rgba(192,38,211,0.8)] animate-pulse" />
              <span className="text-[10px] font-bold text-fuchsia-300 uppercase tracking-widest">Decentralized</span>
            </div>
            <h2 className="text-4xl md:text-5xl font-serif font-medium text-white tracking-tight mb-4">Ghost Operators</h2>
            <p className="text-lg text-zinc-400">Anyone can run a bot that auto-compounds vaults and earn fees. No permission needed.</p>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="bg-black/40 border border-purple-500/10 rounded-3xl p-8 flex flex-col items-center text-center gap-4 hover:border-purple-500/30 transition-colors shadow-xl">
              <div className="w-16 h-16 bg-purple-500/10 border border-purple-500/20 rounded-full flex items-center justify-center text-3xl shadow-inner mb-2">🔑</div>
              <h3 className="text-xl font-serif font-medium text-white tracking-tight">Register</h3>
              <p className="text-zinc-400 leading-relaxed text-sm">Call registerAsGhost() — free, no stake. Your address is now eligible to compound any vault.</p>
            </div>
            <div className="bg-black/40 border border-purple-500/10 rounded-3xl p-8 flex flex-col items-center text-center gap-4 hover:border-purple-500/30 transition-colors shadow-xl">
              <div className="w-16 h-16 bg-purple-500/10 border border-purple-500/20 rounded-full flex items-center justify-center text-3xl shadow-inner mb-2">🤖</div>
              <h3 className="text-xl font-serif font-medium text-white tracking-tight">Run a Bot</h3>
              <p className="text-zinc-400 leading-relaxed text-sm">A simple Node.js script calls compound() every hour. 10 lines of code, runs on any server.</p>
            </div>
            <div className="bg-black/40 border border-purple-500/10 rounded-3xl p-8 flex flex-col items-center text-center gap-4 hover:border-purple-500/30 transition-colors shadow-xl">
              <div className="w-16 h-16 bg-purple-500/10 border border-purple-500/20 rounded-full flex items-center justify-center text-3xl shadow-inner mb-2">💰</div>
              <h3 className="text-xl font-serif font-medium text-white tracking-tight">Earn 0.1%</h3>
              <p className="text-zinc-400 leading-relaxed text-sm">Every compound earns you 0.1% of the yield. Ghost can ONLY compound — cannot withdraw or steal funds.</p>
            </div>
          </div>
          
          <div className="flex justify-center mt-10">
            <Link href="/ghosts" className="px-8 py-3.5 rounded-full border border-purple-500/30 bg-purple-500/10 text-sm font-semibold text-purple-300 transition-all duration-300 hover:bg-purple-500/20 hover:text-purple-200 hover:border-purple-500/50">
              Become a Ghost Operator →
            </Link>
          </div>
        </div>
      </section>

      {/* ── 5. Why Drip (Parallax Image) ── */}
      <section className="relative z-20 py-32 bg-[#0a0a0a] bg-[url('/why-bg.png')] bg-cover bg-center bg-fixed">
        <div className="absolute inset-0 bg-black/50"></div>
        <div className="absolute top-0 inset-x-0 h-32 bg-gradient-to-b from-[#050505] to-transparent"></div>
        <div className="absolute bottom-0 inset-x-0 h-32 bg-gradient-to-t from-[#0a0718] to-transparent"></div>
        
        <div className="section-container relative z-10">
          <div className="max-w-3xl mx-auto text-center flex flex-col items-center gap-10">
            
            <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-[0.3em]">
              A Protocol Companion
            </span>
            
            <h2 className="text-4xl md:text-5xl lg:text-6xl font-serif font-medium text-white tracking-tight leading-[1.1]">
              Adventure inspired.<br />
              <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-purple-500">
                Yield driven.
              </span>
            </h2>
            
            <p className="text-lg text-zinc-300 leading-relaxed max-w-xl">
              One deposit. Eight contracts working in unison. Your vault auto-compounds through lending markets, 
              defends against oracle drops, and battles rival vaults — all without you lifting a finger.
            </p>

            {/* Highlighted stats bar */}
            <div className="flex items-center justify-center gap-0 mt-4 bg-white/[0.04] backdrop-blur-xl border border-white/[0.08] rounded-2xl px-2 py-5 shadow-[0_0_40px_rgba(59,130,246,0.06)]">
              {[
                { value: '8%', label: 'Base APY' },
                { value: '~120k', label: 'TVL in INIT' },
                { value: '0', label: 'Gas for depositors' },
                { value: '24/7', label: 'Auto-compound' },
              ].map((stat, i) => (
                <div key={stat.label} className="flex items-center">
                  <div className="flex flex-col items-center gap-1.5 px-6 md:px-10">
                    <span className="text-3xl md:text-4xl font-mono font-bold text-transparent bg-clip-text bg-gradient-to-b from-white to-blue-300 tracking-tight drop-shadow-[0_0_12px_rgba(96,165,250,0.4)]">
                      {stat.value}
                    </span>
                    <span className="text-[9px] font-bold text-zinc-500 uppercase tracking-widest">{stat.label}</span>
                  </div>
                  {i < 3 && <div className="w-px h-10 bg-gradient-to-b from-transparent via-white/10 to-transparent shrink-0" />}
                </div>
              ))}
            </div>

            <Link 
              href="/docs" 
              className="mt-4 px-8 py-3.5 rounded-full border border-white/10 bg-white/5 text-sm font-semibold text-zinc-300 text-center transition-all duration-300 hover:bg-white/10 hover:text-white hover:border-white/20"
            >
              Read the documentation →
            </Link>
          </div>
        </div>
      </section>

      {/* ── 6. Final CTA Band ── */}
      <section className="relative z-20 py-24 bg-gradient-to-b from-[#050505] via-[#0a0718] to-[#050505]">
        <div className="section-container relative z-10">
          <div className="max-w-3xl mx-auto text-center flex flex-col items-center gap-8">
            <h2 className="text-4xl md:text-5xl font-serif font-medium text-white tracking-tight">
              Ready to drip?
            </h2>
            <p className="text-lg text-zinc-400 max-w-xl">
              Connect your wallet, deposit into a vault, and let the protocol do the rest. 
              Your yield compounds while you sleep.
            </p>
            <div className="flex flex-col sm:flex-row gap-4">
              <div className="[&_button]:px-10 [&_button]:py-4 [&_button]:text-base">
                <ConnectButton />
              </div>
              <Link 
                href="/docs" 
                className="px-10 py-4 rounded-full border border-white/10 bg-white/5 text-base font-semibold text-zinc-300 text-center transition-all duration-300 hover:bg-white/10 hover:text-white hover:border-white/20 flex items-center justify-center"
              >
                Read the Docs
              </Link>
            </div>
          </div>
        </div>
      </section>

    </main>
  );
}