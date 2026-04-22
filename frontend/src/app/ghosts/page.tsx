'use client';

import { useState, useEffect } from 'react';
import { useAccount, useWriteContract, useSwitchChain } from 'wagmi';
import { createPublicClient, http, formatEther } from 'viem';
import { useInterwovenKit } from '@initia/interwovenkit-react';

import { GhostRegistryABI, GhostRegistryAddress } from '@/lib/contracts';
import { DRIP_RPC_URL, DRIP_CHAIN_ID } from '@/lib/chain';

const publicClient = createPublicClient({
  transport: http(DRIP_RPC_URL),
});

const TARGET_CHAIN_ID = DRIP_CHAIN_ID;

type GhostStats = {
  compoundsExecuted: number;
  successfulCompounds: number;
  totalYieldManaged: bigint;
  pendingRewards: bigint;
  totalFeesEarned: bigint;
  registeredAt: number;
};

export default function GhostsPage() {
  const { isConnected, hexAddress } = useInterwovenKit();
  const { address: wagmiAddress } = useAccount();
  const { switchChainAsync } = useSwitchChain();
  const { writeContractAsync } = useWriteContract();
  
  const address = wagmiAddress || hexAddress;
  
  const [isWorking, setIsWorking] = useState(false);
  const [claimWorking, setClaimWorking] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [claimSuccess, setClaimSuccess] = useState(false);
  const [isRegistered, setIsRegistered] = useState(false);
  const [myStats, setMyStats] = useState<GhostStats | null>(null);
  const [topGhosts, setTopGhosts] = useState<{ address: string; compounds: number; yieldManaged: string }[]>([]);
  const [loading, setLoading] = useState(true);

  // Fetch registration state + ghost list from chain
  useEffect(() => {
    async function fetchGhostData() {
      try {
        // Check if user is registered
        if (address) {
          const registered = await publicClient.readContract({
            address: GhostRegistryAddress as `0x${string}`,
            abi: GhostRegistryABI,
            functionName: 'registeredGhosts',
            args: [address as `0x${string}`],
          }) as boolean;
          setIsRegistered(registered);

          if (registered) {
            const stats = await publicClient.readContract({
              address: GhostRegistryAddress as `0x${string}`,
              abi: GhostRegistryABI,
              functionName: 'ghostStats',
              args: [address as `0x${string}`],
            }) as any;
            setMyStats({
              compoundsExecuted: Number(stats[0]),
              successfulCompounds: Number(stats[1]),
              totalYieldManaged: BigInt(stats[2]),
              pendingRewards: BigInt(stats[3]),
              totalFeesEarned: BigInt(stats[4]),
              registeredAt: Number(stats[5]),
            });
          }
        }

        // Fetch ghost list
        const ghostCount = await publicClient.readContract({
          address: GhostRegistryAddress as `0x${string}`,
          abi: GhostRegistryABI,
          functionName: 'ghostListLength',
        }) as bigint;

        const ghosts: { address: string; compounds: number; yieldManaged: string }[] = [];
        for (let i = 0; i < Math.min(Number(ghostCount), 10); i++) {
          try {
            const ghostAddr = await publicClient.readContract({
              address: GhostRegistryAddress as `0x${string}`,
              abi: GhostRegistryABI,
              functionName: 'ghostList',
              args: [BigInt(i)],
            }) as string;

            const stats = await publicClient.readContract({
              address: GhostRegistryAddress as `0x${string}`,
              abi: GhostRegistryABI,
              functionName: 'ghostStats',
              args: [ghostAddr as `0x${string}`],
            }) as any;

            ghosts.push({
              address: ghostAddr,
              compounds: Number(stats[0]),
              yieldManaged: `${Number(formatEther(BigInt(stats[2]))).toLocaleString('en-US', { maximumFractionDigits: 2 })} INIT`,
            });
          } catch {}
        }
        setTopGhosts(ghosts);
      } catch (err) {
        console.error('Failed to fetch ghost data:', err);
      } finally {
        setLoading(false);
      }
    }
    fetchGhostData();
  }, [address, isWorking]);

  const truncateAddress = (addr: string) => `${addr.slice(0, 6)}...${addr.slice(-4)}`;

  const handleRegister = async () => {
    if (!address) return;
    
    setIsWorking(true);
    setError(null);

    try {
      try { await switchChainAsync({ chainId: TARGET_CHAIN_ID }); } catch {}

      await writeContractAsync({
        address: GhostRegistryAddress as `0x${string}`,
        abi: GhostRegistryABI,
        functionName: 'registerAsGhost',
      });

      setIsRegistered(true);
    } catch (err: any) {
      console.error('Register error:', err);
      setError(err.shortMessage || err.message || "Transaction rejected or failed");
    } finally {
      setIsWorking(false);
    }
  };

  return (
    <main className="min-h-screen bg-gradient-to-b from-[#0d0520] via-[#080312] to-[#050505] pt-12 pb-24 relative overflow-hidden">
      
      {/* ── Ambient Purple Glow ── */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full max-w-4xl h-64 bg-gradient-to-b from-purple-500/15 to-transparent blur-[100px] pointer-events-none" />
      <div className="absolute bottom-0 right-0 w-[400px] h-[300px] bg-fuchsia-700/8 rounded-full blur-[120px] pointer-events-none" />

      <div className="max-w-7xl mx-auto px-6 relative z-10">
        
        {/* ── Page Header ── */}
        <div className="flex flex-col items-center text-center gap-4 mb-16">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full border border-emerald-500/20 bg-emerald-500/10">
            <span className="w-2 h-2 rounded-full bg-emerald-400 shadow-[0_0_8px_rgba(52,211,153,0.8)] animate-pulse" />
            <span className="text-[10px] font-bold text-emerald-300 uppercase tracking-widest">
              Ghost Infrastructure
            </span>
          </div>
          
          <h1 className="text-5xl md:text-6xl font-serif font-medium text-white tracking-tight">
            Operator Network
          </h1>
          
          <p className="text-lg text-zinc-400 max-w-2xl leading-relaxed">
            Register as a decentralized bot operator. Execute auto-compounds for vaults and earn performance fees entirely gas-free via Initia.
          </p>
        </div>

        {/* ── Main Layout Grid ── */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
          
          {/* Left Column: Leaderboard (Takes up 8/12 cols on desktop) */}
          <div className="lg:col-span-8 flex flex-col">
            
            <h3 className="text-2xl font-serif font-medium text-white mb-6">Top Operators</h3>

            <div className="bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-3xl p-6 md:p-8 shadow-2xl flex flex-col">
              
              {/* Table Header */}
              <div className="grid grid-cols-[60px_1fr_100px_100px] sm:grid-cols-[60px_1fr_100px_120px] px-4 py-3 text-[10px] font-bold text-zinc-500 uppercase tracking-widest border-b border-white/10 mb-2">
                <span>Rank</span>
                <span>Ghost Address</span>
                <span className="text-right">Compounds</span>
                <span className="text-right">Yield Mngd</span>
              </div>

              {/* Table Rows */}
              <div className="flex flex-col gap-1">
                {topGhosts.length === 0 && !loading ? (
                  <div className="py-8 text-center text-sm text-zinc-500">No ghost operators registered yet. Be the first!</div>
                ) : topGhosts.map((ghost: { address: string; compounds: number; yieldManaged: string }, i: number) => {
                  const isFirst = i === 0;

                  return (
                    <div 
                      key={ghost.address} 
                      className={`grid grid-cols-[60px_1fr_100px_100px] sm:grid-cols-[60px_1fr_100px_120px] items-center px-4 py-3.5 rounded-xl transition-colors ${
                        isFirst 
                          ? 'bg-emerald-500/10 border border-emerald-500/20 relative overflow-hidden' 
                          : 'hover:bg-white/5 border border-transparent'
                      }`}
                    >
                      {isFirst && (
                        <div className="absolute top-0 left-0 w-1/2 h-full bg-gradient-to-r from-emerald-400/10 to-transparent pointer-events-none" />
                      )}

                      <span className={`relative z-10 font-serif text-lg font-bold ${
                        isFirst ? 'text-emerald-400 drop-shadow-[0_0_8px_rgba(52,211,153,0.5)]' : 'text-zinc-500'
                      }`}>
                        #{i + 1}
                      </span>

                      <span className={`relative z-10 font-mono text-sm font-medium pr-2 ${
                        isFirst ? 'text-white' : 'text-zinc-300'
                      }`}>
                        {truncateAddress(ghost.address)}
                      </span>

                      <span className="relative z-10 font-mono text-sm sm:text-base font-medium text-right text-zinc-300">
                        {ghost.compounds}
                      </span>

                      <span className="relative z-10 font-mono text-sm sm:text-base font-bold text-right text-transparent bg-clip-text bg-gradient-to-r from-emerald-400 to-cyan-500">
                        {ghost.yieldManaged}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
          
          {/* Right Column: Operator Terminal */}
          <div className="lg:col-span-4 sticky top-32">
            <div className="bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-3xl p-6 md:p-8 shadow-2xl flex flex-col gap-6">
              
              <div className="flex items-center gap-3 border-b border-white/10 pb-5">
                <div className="p-2 bg-white/5 rounded-lg border border-white/10">
                  <svg className="w-5 h-5 text-zinc-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 9l3 3-3 3m5 0h3M4 12a8 8 0 1116 0 8 8 0 01-16 0z" />
                  </svg>
                </div>
                <h3 className="text-xl font-serif font-medium text-white tracking-tight">Operator Terminal</h3>
              </div>

              {!isConnected ? (
                <div className="py-8 text-center flex flex-col items-center gap-3">
                  <span className="text-3xl opacity-50">🔌</span>
                  <p className="text-sm text-zinc-400 font-medium">Connect wallet to view your operator status.</p>
                </div>
              ) : !isRegistered ? (
                <div className="flex flex-col gap-4">
                  <p className="text-sm text-zinc-400 leading-relaxed">
                    You are not currently registered as a Ghost Operator. Registering allows vault creators to delegate compounding tasks to your address.
                  </p>
                  
                  {error && (
                    <div className="text-xs font-medium text-red-400 bg-red-500/10 border border-red-500/20 p-3 rounded-lg text-center">
                      {error}
                    </div>
                  )}

                  <button 
                    onClick={handleRegister}
                    disabled={isWorking}
                    className="w-full py-4 rounded-xl font-semibold transition-all duration-300 flex justify-center items-center gap-2 mt-2 bg-white text-black hover:bg-zinc-200 shadow-[0_4px_20px_rgba(255,255,255,0.15)] hover:-translate-y-0.5 disabled:opacity-50"
                  >
                    {isWorking ? (
                      <>
                        <svg className="animate-spin h-5 w-5 text-current" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                          <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                        </svg>
                        Registering...
                      </>
                    ) : 'Register as Ghost'}
                  </button>
                </div>
              ) : (
                <div className="flex flex-col gap-4">
                  <div className="flex justify-between items-center py-3 border-b border-white/5">
                    <span className="text-xs font-bold text-zinc-500 uppercase tracking-widest">Status</span>
                    <span className="text-sm font-semibold text-emerald-400 flex items-center gap-2">
                      <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                      Active
                    </span>
                  </div>
                  <div className="flex justify-between items-center py-3 border-b border-white/5">
                    <span className="text-xs font-bold text-zinc-500 uppercase tracking-widest">Compounds Executed</span>
                    <span className="text-sm font-mono font-medium text-white">{myStats?.compoundsExecuted || 0}</span>
                  </div>
                  <div className="flex justify-between items-center py-3 border-b border-white/5">
                    <span className="text-xs font-bold text-zinc-500 uppercase tracking-widest">Success Rate</span>
                    <span className="text-sm font-mono font-medium text-white">
                      {myStats && myStats.compoundsExecuted > 0 
                        ? `${((myStats.successfulCompounds / myStats.compoundsExecuted) * 100).toFixed(1)}%` 
                        : '—'}
                    </span>
                  </div>
                  <div className="flex justify-between items-center py-3">
                    <span className="text-xs font-bold text-zinc-500 uppercase tracking-widest">Fees Earned</span>
                    <span className="text-sm font-mono font-bold text-transparent bg-clip-text bg-gradient-to-r from-emerald-400 to-cyan-500">
                      {myStats ? Number(formatEther(myStats.totalFeesEarned)).toLocaleString('en-US', { maximumFractionDigits: 4 }) : '0'} INIT
                    </span>
                  </div>
                  <div className="mt-4 pt-4 border-t border-white/5">
                    <p className="text-xs text-zinc-500 leading-relaxed">
                      Ghost operators run automated bots that call{' '}
                      <code className="bg-white/10 text-zinc-300 px-1 rounded">compound()</code>{' '}
                      on delegated vaults and earn 0.1% of yield harvested.{' '}
                      <a href="/docs#ghosts" className="text-emerald-400 hover:text-emerald-300 underline underline-offset-2">
                        Learn how to run a bot →
                      </a>
                    </p>
                  </div>
                  {claimSuccess && (
                    <div className="text-xs font-medium text-emerald-400 bg-emerald-500/10 border border-emerald-500/20 p-3 rounded-lg text-center">
                      Fees claimed successfully!
                    </div>
                  )}
                  <button 
                    onClick={async () => {
                      if (!address) return;
                      setClaimWorking(true);
                      setClaimSuccess(false);
                      setError(null);
                      try {
                        try { await switchChainAsync({ chainId: TARGET_CHAIN_ID }); } catch {}
                        await writeContractAsync({
                          chainId: TARGET_CHAIN_ID,
                          address: GhostRegistryAddress as `0x${string}`,
                          abi: GhostRegistryABI,
                          functionName: 'claimGhostRewards',
                        });
                        setClaimSuccess(true);
                      } catch (err: any) {
                        console.error('Claim error:', err);
                        setError(err.shortMessage || err.message || 'Claim failed');
                      } finally {
                        setClaimWorking(false);
                      }
                    }}
                    disabled={claimWorking || (myStats?.pendingRewards === BigInt(0))}
                    className="w-full mt-4 py-3.5 rounded-xl border border-white/10 bg-white/5 text-sm font-semibold text-zinc-300 transition-all duration-300 hover:bg-white/10 hover:text-white hover:border-white/20 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {claimWorking ? 'Claiming...' : 'Claim Fees'}
                  </button>
                </div>
              )}

            </div>
          </div>

        </div>
      </div>
    </main>
  );
}