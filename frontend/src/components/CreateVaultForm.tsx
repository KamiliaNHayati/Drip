'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useSwitchChain, useChainId } from 'wagmi';
import { parseEther } from 'viem';
import { useInterwovenKit } from '@initia/interwovenkit-react';

import { VaultFactoryABI, VaultFactoryAddress } from '@/lib/contracts';

export default function CreateVaultForm() {
  const router = useRouter();
  const { isConnected, hexAddress } = useInterwovenKit();
  const { address: wagmiAddress } = useAccount();
  const chainId = useChainId();
  const { switchChainAsync } = useSwitchChain();
  
  // Use wagmi address if available, fall back to InterwovenKit hexAddress
  const address = wagmiAddress || (hexAddress as `0x${string}` | undefined);
  
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [fee, setFee] = useState(10);
  const [defensiveThreshold, setDefensiveThreshold] = useState(3);
  
  const [error, setError] = useState<string | null>(null);

  const { writeContractAsync, data: txHash, isPending } = useWriteContract();
  
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  // Redirect on success
  if (isSuccess) {
    setTimeout(() => router.push('/'), 1500);
  }

  const isWorking = isPending || isConfirming;

  const handleCreate = async () => {
    if (!name || !description || !address) {
      console.log('Missing fields:', { name, description, address, hexAddress, wagmiAddress });
      setError('Please fill in all fields and connect wallet');
      return;
    }
    
    setError(null);

    try {
      // Always switch to evm-1 before sending
      const targetChainId = 2124225178762456;
      try {
        await switchChainAsync({ chainId: targetChainId });
      } catch (switchErr) {
        console.log('Chain switch skipped or failed:', switchErr);
      }

      console.log('Sending createVault tx...', { address, name, fee: fee * 100 });

      const hash = await writeContractAsync({
        address: VaultFactoryAddress as `0x${string}`,
        abi: VaultFactoryABI,
        functionName: 'createVault',
        args: [name, description, BigInt(fee * 100)],
        value: parseEther('3'),
      });

      console.log('Tx submitted:', hash);
    } catch (err: any) {
      console.error('CreateVault error:', err);
      setError(err.shortMessage || err.message || "Transaction rejected");
    }
  };

  return (
    <div className="bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-3xl p-8 max-w-2xl mx-auto flex flex-col gap-8 shadow-2xl">
      
      {/* Header */}
      <div>
        <h2 className="text-3xl font-serif font-medium text-white tracking-tight m-0">
          Deploy Vault
        </h2>
        <p className="text-zinc-400 mt-2">
          Create a branded yield strategy. Define your fees and defensive parameters.
        </p>
      </div>

      <div className="flex flex-col gap-6">
        
        {/* Name Input */}
        <div className="flex flex-col gap-2">
          <label className="text-sm font-semibold text-zinc-300 uppercase tracking-wide">
            Vault Name
          </label>
          <input 
            type="text" 
            placeholder="e.g. Degen Spartans" 
            value={name}
            onChange={(e) => setName(e.target.value)}
            disabled={isWorking}
            maxLength={30}
            className="bg-black/50 border border-white/10 focus:border-purple-500 focus:ring-1 focus:ring-purple-500/50 rounded-xl px-4 py-3 text-white placeholder:text-zinc-600 transition-all outline-none"
          />
        </div>

        {/* Description Input */}
        <div className="flex flex-col gap-2">
          <label className="text-sm font-semibold text-zinc-300 uppercase tracking-wide">
            Strategy Description
          </label>
          <textarea 
            placeholder="What is your vault's strategy?" 
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            disabled={isWorking}
            maxLength={150}
            rows={3}
            className="bg-black/50 border border-white/10 focus:border-purple-500 focus:ring-1 focus:ring-purple-500/50 rounded-xl px-4 py-3 text-white placeholder:text-zinc-600 transition-all outline-none resize-none"
          />
        </div>

        {/* Sliders Row */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-6 p-5 bg-white/5 border border-white/5 rounded-2xl">
          
          <div className="flex flex-col gap-3">
            <div className="flex justify-between items-center">
              <label className="text-xs font-bold text-zinc-400 uppercase tracking-widest">
                Creator Fee
              </label>
              <span className="text-sm font-mono text-blue-400 font-semibold">{fee}%</span>
            </div>
            <input 
              type="range" 
              min="5" 
              max="20" 
              step="1"
              value={fee}
              onChange={(e) => setFee(Number(e.target.value))}
              disabled={isWorking}
              className="w-full accent-blue-500 h-1 bg-white/10 rounded-lg appearance-none cursor-pointer"
            />
            <span className="text-[10px] text-zinc-500 uppercase tracking-wider">
              Taken on profit only
            </span>
          </div>

          <div className="flex flex-col gap-3">
            <div className="flex justify-between items-center">
              <label className="text-xs font-bold text-zinc-400 uppercase tracking-widest">
                Defensive Drops
              </label>
              <span className="text-sm font-mono text-purple-400 font-semibold">{defensiveThreshold}</span>
            </div>
            <input 
              type="range" 
              min="1" 
              max="5" 
              step="1"
              value={defensiveThreshold}
              onChange={(e) => setDefensiveThreshold(Number(e.target.value))}
              disabled={isWorking}
              className="w-full accent-purple-500 h-1 bg-white/10 rounded-lg appearance-none cursor-pointer"
            />
            <span className="text-[10px] text-zinc-500 uppercase tracking-wider">
              Oracle consecutive drops
            </span>
          </div>
        </div>
      </div>

      {/* Summary & Submit */}
      <div className="flex flex-col gap-4 mt-2">
        <div className="flex justify-between items-center px-5 py-4 bg-black/60 border border-white/5 rounded-xl border-dashed">
          <span className="text-sm font-semibold text-zinc-400 uppercase tracking-wide">Creation Cost</span>
          <span className="text-xl font-mono font-bold text-white">3.0 <span className="text-sm text-zinc-500">INIT</span></span>
        </div>

        {error && (
          <div className="p-3 rounded-lg bg-red-500/10 border border-red-500/20 text-red-400 text-sm text-center">
            {error}
          </div>
        )}

        {isSuccess && (
          <div className="p-3 rounded-lg bg-green-500/10 border border-green-500/20 text-green-400 text-sm text-center">
            ✓ Vault deployed! Redirecting...
          </div>
        )}

        <button 
          onClick={handleCreate}
          disabled={isWorking || !name || !description || !isConnected}
          className={`w-full py-4 rounded-xl font-semibold transition-all duration-300 flex justify-center items-center gap-2 ${
            !isConnected || !name || !description
              ? 'bg-white/10 text-zinc-500 cursor-not-allowed'
              : 'bg-white text-black hover:bg-zinc-200 shadow-[0_4px_20px_rgba(255,255,255,0.15)] hover:-translate-y-0.5'
          }`}
        >
          {!isConnected ? 'Connect Wallet to Deploy' : (
            isWorking ? (
              <>
                <svg className="animate-spin h-5 w-5 text-current" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                {isPending ? 'Confirm in wallet...' : 'Deploying Vault...'}
              </>
            ) : 'Deploy Vault'
          )}
        </button>
      </div>

    </div>
  );
}