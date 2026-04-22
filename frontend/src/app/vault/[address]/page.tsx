'use client';

import { useState, useEffect } from 'react';
import { useParams } from 'next/navigation';
import { createPublicClient, http, formatEther, parseEther, erc20Abi } from 'viem';
import { useAccount, useWriteContract, useSwitchChain } from 'wagmi';
import { useInterwovenKit } from '@initia/interwovenkit-react';
import DefensiveStatus from '@/components/DefensiveStatus';
import DepositForm from '@/components/DepositForm';
import WithdrawForm from '@/components/WithdrawForm';
import { DripVaultABI, GhostRegistryAddress, GhostRegistryABI, INIT_TOKEN } from '@/lib/contracts';
import { DRIP_RPC_URL, DRIP_CHAIN_ID } from '@/lib/chain';

const publicClient = createPublicClient({
  transport: http(DRIP_RPC_URL),
});

const TARGET_CHAIN_ID = DRIP_CHAIN_ID;

type VaultInfo = {
  name: string;
  description: string;
  creator: string;
  creatorFeeBps: number;
  totalAssets: bigint;
  totalShares: bigint;
  depositorCount: number;
  paused: boolean;
  defensiveMode: boolean;
};

export default function VaultDetailPage() {
  const params = useParams();
  const address = params.address as `0x${string}`;
  const [activeTab, setActiveTab] = useState<'deposit' | 'withdraw'>('deposit');

  const { isConnected, hexAddress } = useInterwovenKit();
  const { address: wagmiAddress } = useAccount();
  const { switchChainAsync } = useSwitchChain();
  const { writeContractAsync } = useWriteContract();
  const userAddress = wagmiAddress || (hexAddress as `0x${string}` | undefined);

  // On-chain vault data
  const [vaultInfo, setVaultInfo] = useState<VaultInfo | null>(null);
  const [userShares, setUserShares] = useState<bigint>(BigInt(0));
  const [userBalance, setUserBalance] = useState<bigint>(BigInt(0));
  const [loading, setLoading] = useState(true);
  const [ghostWorking, setGhostWorking] = useState(false);
  const [ghostError, setGhostError] = useState<string | null>(null);
  const [delegatedGhost, setDelegatedGhost] = useState<string | null>(null);

  // AutoSign is tied to ghost delegation — if a ghost is set, auto-compounding is active
  const hasGhost = delegatedGhost !== null && delegatedGhost !== '0x0000000000000000000000000000000000000000';
  const [autoSignLoading, setAutoSignLoading] = useState(false);
  const [autoSignError, setAutoSignError] = useState<string | null>(null);

  const truncateAddress = (addr: string) => {
    if (!addr) return '';
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };

  // Fetch vault info + user position from chain
  useEffect(() => {
    async function fetchData() {
      try {
        const info = await publicClient.readContract({
          address: address,
          abi: DripVaultABI,
          functionName: 'vaultInfo',
        }) as any;

        setVaultInfo({
          name: info[0] || 'Unnamed Vault',
          description: info[1] || '',
          creator: info[2] || '',
          creatorFeeBps: Number(info[3] || 0),
          totalAssets: BigInt(info[4] || 0),
          totalShares: BigInt(info[5] || 0),
          depositorCount: Number(info[6] || 0),
          paused: Boolean(info[7]),
          defensiveMode: Boolean(info[8]),
        });

        // Fetch delegated ghost from chain
        try {
          const ghost = await publicClient.readContract({
            address: address,
            abi: DripVaultABI,
            functionName: 'delegatedGhost',
          }) as string;
          setDelegatedGhost(ghost);
        } catch {}

        // Fetch user-specific data
        if (userAddress) {
          try {
            const shares = await publicClient.readContract({
              address: address,
              abi: DripVaultABI,
              functionName: 'getSharesOf',
              args: [userAddress as `0x${string}`],
            }) as bigint;
            setUserShares(shares);
          } catch {}

          try {
            const bal = await publicClient.readContract({
              address: INIT_TOKEN as `0x${string}`,
              abi: erc20Abi,
              functionName: 'balanceOf',
              args: [userAddress as `0x${string}`],
            }) as bigint;
            setUserBalance(bal);
          } catch {}
        }
      } catch (err) {
        console.error('Failed to fetch vault info:', err);
      } finally {
        setLoading(false);
      }
    }
    fetchData();
  }, [address, userAddress]);

  // Ghost delegation handler
  const handleSetGhost = async () => {
    if (!userAddress) return;
    setGhostWorking(true);
    setGhostError(null);

    try {
      try { await switchChainAsync({ chainId: TARGET_CHAIN_ID }); } catch {}

      // Delegate self as ghost for demo (in production you'd pick from the ghost leaderboard)
      await writeContractAsync({
        address: address,
        abi: DripVaultABI,
        functionName: 'setDelegatedGhost',
        args: [userAddress as `0x${string}`, GhostRegistryAddress as `0x${string}`],
        value: parseEther('5'),
      });

      setDelegatedGhost(userAddress);
    } catch (err: any) {
      console.error('Ghost delegation error:', err);
      setGhostError(err.shortMessage || err.message || 'Failed');
    } finally {
      setGhostWorking(false);
    }
  };

  // AutoSign handler — same tx as ghost delegation but tracks its own error state
  const handleAutoSign = async () => {
    if (!userAddress) return;
    setAutoSignLoading(true);
    setAutoSignError(null);

    try {
      try { await switchChainAsync({ chainId: TARGET_CHAIN_ID }); } catch {}

      await writeContractAsync({
        address: address,
        abi: DripVaultABI,
        functionName: 'setDelegatedGhost',
        args: [userAddress as `0x${string}`, GhostRegistryAddress as `0x${string}`],
        value: parseEther('5'),
      });

      setDelegatedGhost(userAddress);
    } catch (err: any) {
      console.error('AutoSign error:', err);
      setAutoSignError(err.shortMessage || err.message || 'Failed');
    } finally {
      setAutoSignLoading(false);
    }
  };

  // Formatted display values
  const tvlFormatted = vaultInfo ? Number(formatEther(vaultInfo.totalAssets)).toLocaleString('en-US', { maximumFractionDigits: 2 }) : '...';
  const feePercent = vaultInfo ? (vaultInfo.creatorFeeBps / 100).toFixed(1) : '...';
  const userSharesFormatted = Number(formatEther(userShares)).toLocaleString('en-US', { maximumFractionDigits: 4 });
  const userBalFormatted = Number(formatEther(userBalance)).toLocaleString('en-US', { maximumFractionDigits: 4 });

  if (loading) {
    return (
      <main className="min-h-screen bg-gradient-to-b from-[#0d0520] via-[#080312] to-[#050505] pt-32 flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <svg className="animate-spin h-8 w-8 text-zinc-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <span className="text-sm text-zinc-500 font-medium">Loading vault data...</span>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-gradient-to-b from-[#0d0520] via-[#080312] to-[#050505] pt-12 pb-32 relative overflow-hidden">
      
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full max-w-5xl h-96 bg-gradient-to-b from-purple-500/15 to-transparent blur-[120px] pointer-events-none" />
      <div className="absolute bottom-0 right-0 w-[400px] h-[300px] bg-fuchsia-700/8 rounded-full blur-[120px] pointer-events-none" />

      <div className="max-w-7xl mx-auto px-6 relative z-10">
        
        {/* Vault Header */}
        <div className="flex flex-col gap-4 mb-12 border-b border-white/5 pb-8">
          <div className="flex flex-wrap items-center gap-3">
            <span className="px-3 py-1 bg-white/5 border border-white/10 rounded-md text-[10px] font-bold text-zinc-400 uppercase tracking-widest">
              Drip Rollup
            </span>
            <span className="px-3 py-1 bg-blue-500/10 border border-blue-500/20 rounded-md text-[10px] font-bold text-blue-400 uppercase tracking-widest">
              Verified
            </span>
          </div>
          
          <h1 className="text-5xl md:text-6xl font-serif font-medium text-white tracking-tight drop-shadow-lg">
            {vaultInfo?.name || 'Vault'}
          </h1>
          
          <div className="flex items-center gap-2 text-sm text-zinc-400">
            <span>Managed by</span>
            <span className="font-mono text-zinc-300 bg-white/5 px-2 py-0.5 rounded border border-white/5">
              {truncateAddress(vaultInfo?.creator || '')}
            </span>
          </div>
        </div>

        {/* Main Layout Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 items-start">
          
          {/* Left Panel */}
          <div className="lg:col-span-7 flex flex-col gap-8">
            
            {/* Stats Row */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div className="bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-2xl p-6 flex flex-col gap-2">
                <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Total Value Locked</span>
                <div className="flex items-baseline gap-1.5">
                  <span className="font-mono text-3xl font-semibold text-white tracking-tight">{tvlFormatted}</span>
                  <span className="text-xs font-medium text-zinc-500">INIT</span>
                </div>
              </div>
              
              <div className="bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-2xl p-6 flex flex-col gap-2 relative overflow-hidden">
                <div className="absolute inset-0 bg-gradient-to-br from-blue-500/5 to-purple-500/5 pointer-events-none" />
                <span className="relative z-10 text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Creator Fee</span>
                <div className="relative z-10 flex items-baseline gap-1">
                  <span className="font-mono text-3xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-purple-500 tracking-tight">
                    {feePercent}%
                  </span>
                </div>
              </div>

              <div className="bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-2xl p-6 flex flex-col gap-2">
                <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Depositors</span>
                <span className="font-mono text-3xl font-semibold text-white tracking-tight">{vaultInfo?.depositorCount || 0}</span>
              </div>
            </div>

            {/* System Status */}
            <div className="flex flex-col gap-4">
              <h3 className="text-xl font-serif font-medium text-white tracking-tight border-b border-white/5 pb-2">System Status</h3>
              <DefensiveStatus 
                statusCode={vaultInfo?.defensiveMode ? 'DEFENSIVE' : 'ACTIVE'} 
                consecutiveDrops={0} 
              />
              
              
              {/* AutoSign Section — reflects ghost delegation state */}
              <div className={`relative overflow-hidden mt-6 rounded-2xl border transition-colors duration-500 p-6 flex flex-col gap-6 ${
                hasGhost 
                  ? 'bg-[#0a0a0e] border-purple-500/30 shadow-[0_0_30px_rgba(124,58,237,0.1)]' 
                  : 'bg-black/40 backdrop-blur-md border-white/10'
              }`}>
                {hasGhost && (
                  <div className="absolute inset-0 bg-gradient-to-r from-blue-500/10 to-purple-500/10 pointer-events-none opacity-50" />
                )}
                <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-6">
                  <div className="relative z-10 flex-1">
                    <div className="flex items-center gap-3 mb-2">
                      <span className={`w-2 h-2 rounded-full transition-colors duration-300 ${
                        hasGhost ? 'bg-green-400 shadow-[0_0_10px_rgba(74,222,128,0.6)]' : 'bg-zinc-600'
                      }`} />
                      <h4 className="text-xl font-serif font-medium text-white m-0 tracking-tight">AutoSign Execution</h4>
                    </div>
                    <p className="text-sm text-zinc-400 leading-relaxed max-w-md m-0">
                      {hasGhost 
                        ? `AutoSign is active. Ghost operator ${truncateAddress(delegatedGhost || '')} is auto-compounding your yield.` 
                        : 'Set a Ghost Operator below to enable auto-compounding. The ghost will harvest and reinvest yield 24/7.'}
                    </p>
                  </div>
                  <button
                    onClick={!hasGhost ? handleAutoSign : undefined}
                    disabled={hasGhost || autoSignLoading || !isConnected}
                    className={`relative z-10 shrink-0 px-7 py-3 rounded-full font-medium flex items-center justify-center min-w-[160px] transition-all duration-300 ${
                      hasGhost 
                        ? 'bg-green-500/10 border border-green-500/30 text-green-400 cursor-default' 
                        : 'bg-purple-500/10 border border-purple-500/30 text-purple-300 hover:bg-purple-500/20 hover:border-purple-400/50 hover:text-purple-200 hover:shadow-[0_0_20px_rgba(168,85,247,0.15)] cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed'
                    }`}
                  >
                    {autoSignLoading ? (
                      <>
                        <svg className="animate-spin h-4 w-4 mr-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                          <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                        </svg>
                        Activating...
                      </>
                    ) : hasGhost ? '✓ Active' : 'Activate'}
                  </button>
                </div>
                {autoSignError && (
                  <div className="text-xs text-red-400 bg-red-500/10 border border-red-500/20 p-2.5 rounded-lg relative z-10">{autoSignError}</div>
                )}
              </div>
            </div>

            {/* Ghost Delegation */}
            <div className={`mt-4 p-6 rounded-2xl flex flex-col gap-4 ${
              hasGhost 
                ? 'bg-emerald-500/10 border border-emerald-500/30' 
                : 'bg-emerald-500/5 border border-emerald-500/20'
            }`}>
              <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-6">
                <div className="flex flex-col gap-1">
                  <div className="flex items-center gap-2 mb-1">
                    <span className={`w-2 h-2 rounded-full ${hasGhost ? 'bg-emerald-400 shadow-[0_0_8px_rgba(52,211,153,0.8)] animate-pulse' : 'bg-emerald-400 shadow-[0_0_8px_rgba(52,211,153,0.8)]'}`} />
                    <h4 className="text-sm font-semibold text-white">Ghost Delegation</h4>
                    <span className="px-2 py-0.5 bg-white/10 rounded text-[9px] font-bold uppercase tracking-widest text-zinc-400">Creator Only</span>
                  </div>
                  <p className="text-xs text-zinc-400 leading-relaxed max-w-sm">
                    {hasGhost 
                      ? `Ghost operator ${truncateAddress(delegatedGhost || '')} is delegated to this vault.`
                      : 'Delegate compounding duties to an automated Ghost Operator. 5 INIT setup fee.'}
                  </p>
                </div>
                <button 
                  onClick={handleSetGhost}
                  disabled={ghostWorking || !isConnected || hasGhost}
                  className={`shrink-0 w-full sm:w-auto px-5 py-2.5 rounded-xl border text-xs font-semibold transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 ${
                    hasGhost 
                      ? 'border-emerald-500/30 bg-emerald-500/20 text-emerald-300 cursor-default'
                      : 'border-emerald-500/30 bg-emerald-500/10 text-emerald-400 hover:bg-emerald-500/20 hover:text-emerald-300'
                  }`}
                >
                  {ghostWorking ? (
                    <>
                      <svg className="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                      Setting...
                    </>
                  ) : hasGhost ? '✓ Ghost Delegated' : 'Set Operator'}
                </button>
              </div>
              {ghostError && (
                <div className="text-xs text-red-400 bg-red-500/10 border border-red-500/20 p-2.5 rounded-lg">{ghostError}</div>
              )}
            </div>

          </div>

          {/* Right Panel: Terminal */}
          <div className="lg:col-span-5 sticky top-32">
            <div className="bg-[#0a0a0e]/90 backdrop-blur-2xl border border-white/10 rounded-3xl shadow-2xl flex flex-col overflow-hidden">
              
              {/* Tabs */}
              <div className="flex p-2 bg-black/40 border-b border-white/5">
                <button 
                  className={`flex-1 py-3 rounded-xl text-sm font-semibold transition-all duration-300 ${
                    activeTab === 'deposit' 
                      ? 'bg-white/10 text-white shadow-sm' 
                      : 'text-zinc-500 hover:text-zinc-300 hover:bg-white/5'
                  }`}
                  onClick={() => setActiveTab('deposit')}
                >
                  Deposit
                </button>
                <button 
                  className={`flex-1 py-3 rounded-xl text-sm font-semibold transition-all duration-300 ${
                    activeTab === 'withdraw' 
                      ? 'bg-white/10 text-white shadow-sm' 
                      : 'text-zinc-500 hover:text-zinc-300 hover:bg-white/5'
                  }`}
                  onClick={() => setActiveTab('withdraw')}
                >
                  Withdraw
                </button>
              </div>

              {/* Form */}
              <div className="p-6 md:p-8">
                {activeTab === 'deposit' ? (
                  <DepositForm vaultAddress={address} />
                ) : (
                  <WithdrawForm vaultAddress={address} />
                )}
              </div>

              {/* User Position Footer */}
              <div className="bg-black/60 border-t border-white/5 p-6 flex flex-col gap-3">
                <div className="flex justify-between items-center">
                  <span className="text-xs font-bold text-zinc-500 uppercase tracking-widest">Your Balance</span>
                  <span className="text-sm font-mono font-medium text-zinc-300">~{userBalFormatted} INIT</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-xs font-bold text-zinc-500 uppercase tracking-widest">Vault Shares</span>
                  <span className="text-sm font-mono font-medium text-white">{userSharesFormatted} <span className="text-[10px] text-zinc-500 ml-1">dripINIT</span></span>
                </div>
              </div>

            </div>
          </div>

        </div>
      </div>
    </main>
  );
}