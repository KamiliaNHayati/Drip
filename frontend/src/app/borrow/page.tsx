'use client';

import { useState, useEffect } from 'react';
import { useAccount, useWriteContract, useSwitchChain } from 'wagmi';
import { createPublicClient, http, formatEther, parseEther, erc20Abi } from 'viem';
import { useInterwovenKit } from '@initia/interwovenkit-react';
import { DripPoolABI, DripPoolAddress, INIT_TOKEN } from '@/lib/contracts';
import { DRIP_RPC_URL, DRIP_CHAIN_ID } from '@/lib/chain';

const publicClient = createPublicClient({
  transport: http(DRIP_RPC_URL),
});

const TARGET_CHAIN_ID = DRIP_CHAIN_ID;

export default function BorrowPage() {
  const { isConnected, hexAddress } = useInterwovenKit();
  const { address: wagmiAddress } = useAccount();
  const { switchChainAsync } = useSwitchChain();
  const { writeContractAsync } = useWriteContract();
  const address = wagmiAddress || (hexAddress as `0x${string}` | undefined);

  const [activeTab, setActiveTab] = useState<'borrow' | 'repay' | 'collateral'>('borrow');
  const [amount, setAmount] = useState('');
  const [isWorking, setIsWorking] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // Pool stats
  const [totalDeposits, setTotalDeposits] = useState<bigint>(BigInt(0));
  const [totalBorrowed, setTotalBorrowed] = useState<bigint>(BigInt(0));
  const [interestRate, setInterestRate] = useState(0);
  const [userDebt, setUserDebt] = useState<bigint>(BigInt(0));
  const [userCollateral, setUserCollateral] = useState<bigint>(BigInt(0));
  const [userBalance, setUserBalance] = useState<bigint>(BigInt(0));

  useEffect(() => {
    async function fetchPoolData() {
      try {
        const [deposits, borrowed, rate] = await Promise.all([
          publicClient.readContract({ address: DripPoolAddress as `0x${string}`, abi: DripPoolABI, functionName: 'totalDeposits' }),
          publicClient.readContract({ address: DripPoolAddress as `0x${string}`, abi: DripPoolABI, functionName: 'totalBorrowed' }),
          publicClient.readContract({ address: DripPoolAddress as `0x${string}`, abi: DripPoolABI, functionName: 'interestRateBps' }),
        ]);
        setTotalDeposits(deposits as bigint);
        setTotalBorrowed(borrowed as bigint);
        setInterestRate(Number(rate));

        if (address) {
          const [debt, collateral, bal] = await Promise.all([
            publicClient.readContract({ address: DripPoolAddress as `0x${string}`, abi: DripPoolABI, functionName: 'getActualDebt', args: [address as `0x${string}`] }),
            publicClient.readContract({ address: DripPoolAddress as `0x${string}`, abi: DripPoolABI, functionName: 'borrowerCollateral', args: [address as `0x${string}`] }),
            publicClient.readContract({ address: INIT_TOKEN as `0x${string}`, abi: erc20Abi, functionName: 'balanceOf', args: [address as `0x${string}`] }),
          ]);
          setUserDebt(debt as bigint);
          setUserCollateral(collateral as bigint);
          setUserBalance(bal as bigint);
        }
      } catch (err) {
        console.error('Failed to fetch pool data:', err);
      }
    }
    fetchPoolData();
  }, [address, isWorking]);

  const parsedAmount = amount ? parseEther(amount) : BigInt(0);

  const handleAction = async () => {
    if (!address || parsedAmount <= BigInt(0)) return;
    setIsWorking(true);
    setError(null);
    setSuccess(null);

    try {
      try { await switchChainAsync({ chainId: TARGET_CHAIN_ID }); } catch {}

      if (activeTab === 'collateral') {
        // First approve INIT token
        await writeContractAsync({
          address: INIT_TOKEN as `0x${string}`,
          abi: erc20Abi,
          functionName: 'approve',
          args: [DripPoolAddress as `0x${string}`, parsedAmount],
        });
        await new Promise(r => setTimeout(r, 2000));

        await writeContractAsync({
          address: DripPoolAddress as `0x${string}`,
          abi: DripPoolABI,
          functionName: 'addCollateral',
          args: [parsedAmount],
        });
        setSuccess('Collateral deposited successfully!');
      } else if (activeTab === 'borrow') {
        await writeContractAsync({
          address: DripPoolAddress as `0x${string}`,
          abi: DripPoolABI,
          functionName: 'borrow',
          args: [parsedAmount],
        });
        setSuccess('Borrowed successfully! Repay before your health factor drops.');
      } else {
        // Repay - approve first
        await writeContractAsync({
          address: INIT_TOKEN as `0x${string}`,
          abi: erc20Abi,
          functionName: 'approve',
          args: [DripPoolAddress as `0x${string}`, parsedAmount],
        });
        await new Promise(r => setTimeout(r, 2000));

        await writeContractAsync({
          address: DripPoolAddress as `0x${string}`,
          abi: DripPoolABI,
          functionName: 'repay',
          args: [parsedAmount],
        });
        setSuccess('Repayment successful!');
      }
      setAmount('');
    } catch (err: any) {
      console.error('Borrow error:', err);
      setError(err.shortMessage || err.message || 'Transaction failed');
    } finally {
      setIsWorking(false);
    }
  };

  const utilizationRate = totalDeposits > BigInt(0) 
    ? Number((totalBorrowed * BigInt(10000)) / totalDeposits) / 100 
    : 0;

  const fmt = (val: bigint) => Number(formatEther(val)).toLocaleString('en-US', { maximumFractionDigits: 4 });

  return (
    <main className="min-h-screen bg-gradient-to-b from-[#0d0520] via-[#080312] to-[#050505] pt-12 pb-24 relative overflow-hidden">
      
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full max-w-4xl h-64 bg-gradient-to-b from-purple-500/15 to-transparent blur-[100px] pointer-events-none" />
      <div className="absolute bottom-0 right-0 w-[400px] h-[300px] bg-fuchsia-700/8 rounded-full blur-[120px] pointer-events-none" />

      <div className="max-w-7xl mx-auto px-6 relative z-10">
        
        {/* Header */}
        <div className="flex flex-col items-center text-center gap-4 mb-16">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full border border-orange-500/20 bg-orange-500/10">
            <span className="w-2 h-2 rounded-full bg-orange-400 shadow-[0_0_8px_rgba(251,146,60,0.8)] animate-pulse" />
            <span className="text-[10px] font-bold text-orange-300 uppercase tracking-widest">DripPool Lending</span>
          </div>
          
          <h1 className="text-5xl md:text-6xl font-serif font-medium text-white tracking-tight">
            Borrow & Lend
          </h1>
          
          <p className="text-lg text-zinc-400 max-w-2xl leading-relaxed">
            DripPool is the yield engine behind every vault. Deposit collateral, borrow INIT, and pay interest — that interest flows directly to vault depositors as yield.
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
          
          {/* Left: Pool Stats */}
          <div className="lg:col-span-7 flex flex-col gap-6">
            
            {/* Protocol Stats */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
              <div className="bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-2xl p-5 flex flex-col gap-2">
                <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Total Deposits</span>
                <span className="font-mono text-xl font-semibold text-white">{fmt(totalDeposits)}</span>
                <span className="text-[10px] text-zinc-500">INIT</span>
              </div>
              <div className="bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-2xl p-5 flex flex-col gap-2">
                <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Total Borrowed</span>
                <span className="font-mono text-xl font-semibold text-orange-400">{fmt(totalBorrowed)}</span>
                <span className="text-[10px] text-zinc-500">INIT</span>
              </div>
              <div className="bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-2xl p-5 flex flex-col gap-2">
                <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Interest Rate</span>
                <span className="font-mono text-xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-orange-400 to-red-500">{(interestRate / 100).toFixed(1)}%</span>
                <span className="text-[10px] text-zinc-500">APR</span>
              </div>
              <div className="bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-2xl p-5 flex flex-col gap-2">
                <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Utilization</span>
                <span className="font-mono text-xl font-semibold text-white">{utilizationRate.toFixed(1)}%</span>
                <div className="w-full h-1.5 bg-white/10 rounded-full overflow-hidden">
                  <div className="h-full bg-gradient-to-r from-orange-400 to-red-500 rounded-full transition-all" style={{ width: `${Math.min(utilizationRate, 100)}%` }} />
                </div>
              </div>
            </div>

            {/* How it works */}
            <div className="bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-3xl p-8">
              <h3 className="text-xl font-serif font-medium text-white tracking-tight border-b border-white/5 pb-4 mb-6">How DripPool Works</h3>
              <ul className="flex flex-col gap-5">
                <li className="flex gap-4">
                  <div className="shrink-0 w-8 h-8 rounded-full bg-orange-500/10 border border-orange-500/20 flex items-center justify-center font-mono font-bold text-orange-400 text-sm">1</div>
                  <div className="flex flex-col">
                    <strong className="text-white text-sm mb-1">Vault Depositors Supply INIT</strong>
                    <span className="text-sm text-zinc-400 leading-relaxed">When users deposit into vaults, the INIT is forwarded to DripPool as lending capital.</span>
                  </div>
                </li>
                <li className="flex gap-4">
                  <div className="shrink-0 w-8 h-8 rounded-full bg-orange-500/10 border border-orange-500/20 flex items-center justify-center font-mono font-bold text-orange-400 text-sm">2</div>
                  <div className="flex flex-col">
                    <strong className="text-white text-sm mb-1">Borrowers Add Collateral & Borrow</strong>
                    <span className="text-sm text-zinc-400 leading-relaxed">Borrowers deposit collateral and take INIT loans at {(interestRate / 100).toFixed(1)}% APR interest.</span>
                  </div>
                </li>
                <li className="flex gap-4">
                  <div className="shrink-0 w-8 h-8 rounded-full bg-orange-500/10 border border-orange-500/20 flex items-center justify-center font-mono font-bold text-orange-400 text-sm">3</div>
                  <div className="flex flex-col">
                    <strong className="text-white text-sm mb-1">Interest → Vault Yield</strong>
                    <span className="text-sm text-zinc-400 leading-relaxed">Interest paid by borrowers is distributed as yield to all vault depositors, compounded by Ghost operators.</span>
                  </div>
                </li>
              </ul>
            </div>

            {/* Your Position */}
            {isConnected && (
              <div className="bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-3xl p-8">
                <h3 className="text-xl font-serif font-medium text-white tracking-tight border-b border-white/5 pb-4 mb-6">Your Position</h3>
                <div className="grid grid-cols-3 gap-4">
                  <div className="flex flex-col gap-1">
                    <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Collateral</span>
                    <span className="font-mono text-lg font-semibold text-white">{fmt(userCollateral)}</span>
                    <span className="text-[10px] text-zinc-500">INIT</span>
                  </div>
                  <div className="flex flex-col gap-1">
                    <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Debt</span>
                    <span className="font-mono text-lg font-semibold text-orange-400">{fmt(userDebt)}</span>
                    <span className="text-[10px] text-zinc-500">INIT</span>
                  </div>
                  <div className="flex flex-col gap-1">
                    <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Wallet</span>
                    <span className="font-mono text-lg font-semibold text-white">{fmt(userBalance)}</span>
                    <span className="text-[10px] text-zinc-500">INIT</span>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Right: Action Terminal */}
          <div className="lg:col-span-5 sticky top-32">
            <div className="bg-[#0a0a0e]/90 backdrop-blur-2xl border border-white/10 rounded-3xl shadow-2xl flex flex-col overflow-hidden">
              
              {/* Tabs */}
              <div className="flex p-2 bg-black/40 border-b border-white/5">
                {(['collateral', 'borrow', 'repay'] as const).map(tab => (
                  <button 
                    key={tab}
                    className={`flex-1 py-3 rounded-xl text-sm font-semibold transition-all duration-300 capitalize ${
                      activeTab === tab 
                        ? 'bg-white/10 text-white shadow-sm' 
                        : 'text-zinc-500 hover:text-zinc-300 hover:bg-white/5'
                    }`}
                    onClick={() => { setActiveTab(tab); setError(null); setSuccess(null); }}
                  >
                    {tab === 'collateral' ? 'Add Collateral' : tab}
                  </button>
                ))}
              </div>

              <div className="p-6 md:p-8 flex flex-col gap-5">
                
                <div className="flex flex-col gap-2">
                  <div className="flex justify-between items-center">
                    <label className="text-xs font-bold text-zinc-400 uppercase tracking-widest">
                      {activeTab === 'collateral' ? 'Collateral Amount' : activeTab === 'borrow' ? 'Borrow Amount' : 'Repay Amount'}
                    </label>
                    <span className="text-[10px] text-zinc-500 uppercase tracking-wider">
                      {activeTab === 'repay' ? `Debt: ${fmt(userDebt)} INIT` : `Balance: ${fmt(userBalance)} INIT`}
                    </span>
                  </div>
                  
                  <div className="relative flex items-center bg-black/40 border border-white/10 rounded-xl p-2 transition-all focus-within:border-orange-500 focus-within:ring-1 focus-within:ring-orange-500/50">
                    <input 
                      type="number" 
                      placeholder="0.00" 
                      value={amount}
                      onChange={(e) => setAmount(e.target.value)}
                      min="0"
                      step="0.01"
                      disabled={isWorking}
                      className="w-full bg-transparent outline-none text-white text-xl font-mono px-3 placeholder:text-zinc-600"
                    />
                    <div className="flex items-center gap-1.5 bg-white/5 px-3 py-1.5 rounded-lg border border-white/5 shrink-0">
                      <div className="w-4 h-4 rounded-full bg-gradient-to-tr from-orange-500 to-red-500" />
                      <span className="text-sm font-semibold text-white">INIT</span>
                    </div>
                  </div>
                </div>

                {error && (
                  <div className="text-xs font-medium text-red-400 bg-red-500/10 border border-red-500/20 p-3 rounded-lg text-center">{error}</div>
                )}
                {success && (
                  <div className="text-xs font-medium text-green-400 bg-green-500/10 border border-green-500/20 p-3 rounded-lg text-center">{success}</div>
                )}

                <button 
                  onClick={handleAction}
                  disabled={!amount || parsedAmount <= BigInt(0) || isWorking || !isConnected}
                  className={`w-full py-4 rounded-xl font-semibold transition-all duration-300 flex justify-center items-center gap-2 ${
                    !isConnected || !amount || parsedAmount <= BigInt(0)
                      ? 'bg-white/10 text-zinc-500 cursor-not-allowed'
                      : 'bg-gradient-to-r from-orange-500 to-red-500 text-white hover:from-orange-400 hover:to-red-400 shadow-[0_4px_20px_rgba(249,115,22,0.25)] hover:-translate-y-0.5'
                  }`}
                >
                  {isWorking && (
                    <svg className="animate-spin h-5 w-5 text-current" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                  )}
                  {!isConnected ? 'Connect Wallet' : 
                    isWorking ? 'Processing...' : 
                    activeTab === 'collateral' ? 'Deposit Collateral' : 
                    activeTab === 'borrow' ? 'Borrow INIT' : 'Repay Debt'}
                </button>
              </div>

            </div>
          </div>

        </div>
      </div>
    </main>
  );
}
