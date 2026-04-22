'use client';

import { useState } from 'react';
import { useAccount, useWriteContract, useSwitchChain } from 'wagmi';
import { useInterwovenKit } from '@initia/interwovenkit-react';
import { parseEther } from 'viem';

import { SquadManagerABI, SquadManagerAddress } from '@/lib/contracts';
import { DRIP_CHAIN_ID } from '@/lib/chain';

const TARGET_CHAIN_ID = DRIP_CHAIN_ID;

export default function SquadsPage() {
  const { isConnected } = useInterwovenKit();
  const { address } = useAccount();
  const { switchChainAsync } = useSwitchChain();
  const { writeContractAsync } = useWriteContract();
  
  const [squadName, setSquadName] = useState('');
  const [joinId, setJoinId] = useState('');
  
  const [isWorking, setIsWorking] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const handleCreate = async () => {
    if (!squadName || !address) return;
    
    setIsWorking(true);
    setError(null);
    setSuccess(null);

    try {
      try { await switchChainAsync({ chainId: TARGET_CHAIN_ID }); } catch {}

      await writeContractAsync({
        chainId: TARGET_CHAIN_ID,
        address: SquadManagerAddress as `0x${string}`,
        abi: SquadManagerABI,
        functionName: 'createSquad',
        args: [squadName],
        value: parseEther('5'),
      });

      setSuccess(`Squad "${squadName}" created successfully!`);
      setSquadName('');
    } catch (err: any) {
      console.error('Create squad error:', err);
      setError(err.shortMessage || err.message || "Transaction rejected or failed");
    } finally {
      setIsWorking(false);
    }
  };

  const handleJoin = async () => {
    if (!joinId || !address) return;
    
    setIsWorking(true);
    setError(null);
    setSuccess(null);

    try {
      try { await switchChainAsync({ chainId: TARGET_CHAIN_ID }); } catch {}

      await writeContractAsync({
        address: SquadManagerAddress as `0x${string}`,
        abi: SquadManagerABI,
        functionName: 'joinSquad',
        args: [BigInt(joinId)] as any,
      });

      setSuccess('Joined squad successfully!');
      setJoinId('');
    } catch (err: any) {
      console.error('Join squad error:', err);
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
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full border border-amber-500/20 bg-amber-500/10">
            <span className="w-2 h-2 rounded-full bg-amber-400 shadow-[0_0_8px_rgba(251,191,36,0.8)] animate-pulse" />
            <span className="text-[10px] font-bold text-amber-300 uppercase tracking-widest">
              Social Yield
            </span>
          </div>
          
          <h1 className="text-5xl md:text-6xl font-serif font-medium text-white tracking-tight">
            Social Squads
          </h1>
          
          <p className="text-lg text-zinc-400 max-w-2xl leading-relaxed">
            Team up in 5-player squads to permanently boost your vault yields and synergize with high-TVL players.
          </p>
        </div>

        {/* ── Main Layout Grid ── */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
          
          {/* Left Column: Forms (7/12 cols) */}
          <div className="lg:col-span-7">
            <div className="bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-3xl p-8 shadow-2xl flex flex-col items-center text-center">
              
              <div className="w-16 h-16 rounded-full bg-white/5 border border-white/10 flex items-center justify-center text-2xl mb-4">
                🤝
              </div>
              <h2 className="text-2xl font-serif font-medium text-white mb-2 tracking-tight">You don't have a Squad</h2>
              <p className="text-zinc-400 text-sm mb-10 max-w-md">
                Create your own squad or join an existing one to unlock up to 25% yield boosts across all your vaults.
              </p>

              {/* Messages */}
              {error && (
                <div className="w-full mb-6 text-xs font-medium text-red-400 bg-red-500/10 border border-red-500/20 p-3 rounded-lg text-center">
                  {error}
                </div>
              )}
              {success && (
                <div className="w-full mb-6 text-xs font-medium text-amber-400 bg-amber-500/10 border border-amber-500/20 p-3 rounded-lg text-center">
                  {success}
                </div>
              )}

              {/* Create Squad Box */}
              <div className="w-full bg-black/40 border border-white/5 rounded-2xl p-6 flex flex-col gap-5 text-left">
                <div className="flex justify-between items-center border-b border-white/5 pb-4">
                  <h3 className="font-serif text-lg font-medium text-white">Create a new Squad</h3>
                  <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest bg-white/5 px-2 py-1 rounded-md">5 INIT</span>
                </div>
                
                <div className="flex flex-col gap-2">
                  <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Squad Name</label>
                  <input 
                    type="text" 
                    placeholder="e.g. Mad Lads" 
                    value={squadName}
                    onChange={e => setSquadName(e.target.value)}
                    disabled={isWorking}
                    className="w-full bg-black/50 border border-white/10 focus:border-amber-500 focus:ring-1 focus:ring-amber-500/50 rounded-xl px-4 py-3 text-white placeholder:text-zinc-600 transition-all outline-none"
                  />
                </div>
                
                <button 
                  onClick={handleCreate}
                  disabled={!squadName || isWorking || !isConnected}
                  className={`w-full py-3.5 rounded-xl font-semibold transition-all duration-300 flex justify-center items-center gap-2 ${
                    !isConnected || !squadName
                      ? 'bg-white/10 text-zinc-500 cursor-not-allowed'
                      : 'bg-amber-500 text-black hover:bg-amber-400 shadow-[0_4px_20px_rgba(245,158,11,0.2)]'
                  }`}
                >
                  {!isConnected ? 'Connect Wallet' : (isWorking ? 'Creating...' : 'Create Squad')}
                </button>
              </div>

              {/* Divider */}
              <div className="flex items-center gap-4 w-full my-8 opacity-50">
                <div className="h-px bg-white/20 flex-1" />
                <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">OR</span>
                <div className="h-px bg-white/20 flex-1" />
              </div>

              {/* Join Squad Box */}
              <div className="w-full bg-black/40 border border-white/5 rounded-2xl p-6 flex flex-col gap-5 text-left">
                <div className="border-b border-white/5 pb-4">
                  <h3 className="font-serif text-lg font-medium text-white">Join an existing Squad</h3>
                </div>
                
                <div className="flex flex-col gap-2">
                  <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Invite Code</label>
                  <input 
                    type="text" 
                    placeholder="0x..." 
                    value={joinId}
                    onChange={e => setJoinId(e.target.value)}
                    disabled={isWorking}
                    className="w-full bg-black/50 border border-white/10 focus:border-amber-500 focus:ring-1 focus:ring-amber-500/50 rounded-xl px-4 py-3 text-white placeholder:text-zinc-600 transition-all outline-none font-mono text-sm"
                  />
                </div>
                
                <button 
                  onClick={handleJoin}
                  disabled={!joinId || isWorking || !isConnected}
                  className="w-full py-3.5 rounded-xl border border-white/10 bg-white/5 text-sm font-semibold text-zinc-300 transition-all duration-300 hover:bg-white/10 hover:text-white hover:border-white/20 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Join Squad
                </button>
              </div>

            </div>
          </div>
          
          {/* Right Column: Info (5/12 cols) */}
          <div className="lg:col-span-5 sticky top-32">
            <div className="bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-3xl p-6 shadow-2xl">
              <h3 className="text-xl font-serif font-medium text-white tracking-tight border-b border-white/10 pb-4 mb-6">
                How Squads Work
              </h3>

              
              
              <ul className="flex flex-col gap-6 mt-6">
                <li className="flex gap-4">
                  <div className="shrink-0 w-8 h-8 rounded-full bg-amber-500/10 border border-amber-500/20 flex items-center justify-center font-mono font-bold text-amber-400 text-sm">1</div>
                  <div className="flex flex-col">
                    <strong className="text-white text-sm mb-1">Form a Team</strong>
                    <span className="text-sm text-zinc-400 leading-relaxed">Create a squad for 5 INIT or join one via an invite code. Maximum 5 members per squad.</span>
                  </div>
                </li>
                <li className="flex gap-4">
                  <div className="shrink-0 w-8 h-8 rounded-full bg-amber-500/10 border border-amber-500/20 flex items-center justify-center font-mono font-bold text-amber-400 text-sm">2</div>
                  <div className="flex flex-col">
                    <strong className="text-white text-sm mb-1">Passive Boost</strong>
                    <span className="text-sm text-zinc-400 leading-relaxed">Every member adds a base 1% boost to everyone's total vault yield across the protocol.</span>
                  </div>
                </li>
                <li className="flex gap-4">
                  <div className="shrink-0 w-8 h-8 rounded-full bg-amber-500/10 border border-amber-500/20 flex items-center justify-center font-mono font-bold text-amber-400 text-sm">3</div>
                  <div className="flex flex-col">
                    <strong className="text-white text-sm mb-1">Active Boost</strong>
                    <span className="text-sm text-zinc-400 leading-relaxed">Anyone can pay 10 INIT to activate the squad boost. For 48 hours, the squad receives up to a 25% total yield multiplier on top of base protocol rates.</span>
                  </div>
                </li>
                <li className="flex gap-4">
                  <div className="shrink-0 w-8 h-8 rounded-full bg-amber-500/10 border border-amber-500/20 flex items-center justify-center font-mono font-bold text-amber-400 text-sm">4</div>
                  <div className="flex flex-col">
                    <strong className="text-white text-sm mb-1">Social Synergy</strong>
                    <span className="text-sm text-zinc-400 leading-relaxed">Bring whales. High TVL players combined with high active boost rates benefits the entire squad perfectly evenly.</span>
                  </div>
                </li>
              </ul>
            </div>
          </div>

        </div>
      </div>
    </main>
  );
}