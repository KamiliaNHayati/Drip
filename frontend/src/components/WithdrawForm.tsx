'use client';

import { useState, useEffect } from 'react';
import { useAccount, useWriteContract, useSwitchChain } from 'wagmi';
import { createPublicClient, http, parseUnits, formatEther, erc20Abi } from 'viem';
import { useInterwovenKit } from '@initia/interwovenkit-react';

import { INIT_DECIMALS, DripVaultABI } from '@/lib/contracts';
import { DRIP_RPC_URL, DRIP_CHAIN_ID } from '@/lib/chain';

interface WithdrawFormProps {
  vaultAddress: `0x${string}`;
}

const publicClient = createPublicClient({
  transport: http(DRIP_RPC_URL),
});

const TARGET_CHAIN_ID = DRIP_CHAIN_ID;

export default function WithdrawForm({ vaultAddress }: WithdrawFormProps) {
  const { isConnected, hexAddress } = useInterwovenKit();
  const { address: wagmiAddress } = useAccount();
  const { switchChainAsync } = useSwitchChain();
  
  const address = wagmiAddress || (hexAddress as `0x${string}` | undefined);
  
  const [amount, setAmount] = useState('');
  const [isWorking, setIsWorking] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const [sharesBalance, setSharesBalance] = useState<bigint>(BigInt(0));

  const { writeContractAsync } = useWriteContract();

  // Fetch user's vault shares on mount
  useEffect(() => {
    async function fetchShares() {
      if (!address) return;
      try {
        // Read dripToken address from vault
        const dripToken = await publicClient.readContract({
          address: vaultAddress,
          abi: DripVaultABI,
          functionName: 'dripToken',
        }) as `0x${string}`;

        // Read user's dripToken balance (= their shares)
        const bal = await publicClient.readContract({
          address: dripToken,
          abi: erc20Abi,
          functionName: 'balanceOf',
          args: [address as `0x${string}`],
        }) as bigint;
        
        setSharesBalance(bal);
      } catch (err) {
        console.error('Failed to fetch shares:', err);
      }
    }
    fetchShares();
  }, [address, vaultAddress, isWorking]); // Re-fetch after tx

  const sharesFormatted = Number(formatEther(sharesBalance)).toLocaleString('en-US', { maximumFractionDigits: 4 });
  const parsedShares = amount ? parseUnits(amount, INIT_DECIMALS) : BigInt(0);

  const handleWithdraw = async () => {
    if (!amount || parsedShares <= BigInt(0) || !address) return;
    
    setIsWorking(true);
    setError(null);
    setSuccess(false);

    try {
      try { await switchChainAsync({ chainId: TARGET_CHAIN_ID }); } catch {}

      await writeContractAsync({
        address: vaultAddress,
        abi: DripVaultABI,
        functionName: 'withdraw',
        args: [parsedShares],
      });

      setSuccess(true);
      setAmount('');

    } catch (err: any) {
      console.error('Withdraw error:', err);
      setError(err.shortMessage || err.message || "Transaction rejected or failed");
    } finally {
      setIsWorking(false);
    }
  };

  const handleMax = () => {
    if (sharesBalance > BigInt(0)) {
      setAmount(formatEther(sharesBalance));
    }
  };

  let buttonLabel = 'Withdraw';
  if (!isConnected) buttonLabel = 'Connect Wallet';
  else if (isWorking) buttonLabel = 'Withdrawing...';

  return (
    <div className="flex flex-col gap-5 pt-2">
      
      <div className="flex flex-col gap-2">
        <div className="flex justify-between items-center">
          <label className="text-xs font-bold text-zinc-400 uppercase tracking-widest">
            Withdraw Amount
          </label>
          <span className="text-[10px] text-zinc-500 uppercase tracking-wider">
            Balance: {sharesFormatted} SHARES
          </span>
        </div>
        
        <div className="relative flex items-center bg-black/40 border border-white/10 rounded-xl p-2 transition-all focus-within:border-purple-500 focus-within:ring-1 focus-within:ring-purple-500/50">
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
          
          <div className="flex items-center gap-2 shrink-0 pr-1">
            <button 
              onClick={handleMax}
              disabled={isWorking}
              className="bg-purple-500/10 text-purple-400 hover:bg-purple-500/20 hover:text-purple-300 transition-colors text-[10px] font-bold px-2.5 py-1.5 rounded-lg uppercase tracking-wider disabled:opacity-50 disabled:cursor-not-allowed"
            >
              MAX
            </button>
            <div className="flex items-center gap-1.5 bg-white/5 px-3 py-1.5 rounded-lg border border-white/5">
              <div className="w-4 h-4 rounded-full bg-gradient-to-br from-purple-400 to-pink-600" />
              <span className="text-sm font-semibold text-white">dripINIT</span>
            </div>
          </div>
        </div>
      </div>

      {error && (
        <div className="text-xs font-medium text-red-400 bg-red-500/10 border border-red-500/20 p-3 rounded-lg text-center">
          {error}
        </div>
      )}
      
      {success && (
        <div className="text-xs font-medium text-green-400 bg-green-500/10 border border-green-500/20 p-3 rounded-lg text-center">
          Withdrawal successful! INIT returned to your wallet.
        </div>
      )}

      <button 
        onClick={handleWithdraw}
        disabled={!amount || parsedShares <= BigInt(0) || isWorking || !isConnected}
        className={`w-full py-4 rounded-xl font-semibold transition-all duration-300 flex justify-center items-center gap-2 ${
          !isConnected || !amount || parsedShares <= BigInt(0)
            ? 'bg-white/10 text-zinc-500 cursor-not-allowed'
            : 'bg-white text-black hover:bg-zinc-200 shadow-[0_4px_20px_rgba(255,255,255,0.15)] hover:-translate-y-0.5'
        }`}
      >
        {isWorking && (
          <svg className="animate-spin h-5 w-5 text-current" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        )}
        {buttonLabel}
      </button>

    </div>
  );
}