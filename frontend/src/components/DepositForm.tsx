'use client';

import { useState, useEffect } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useSwitchChain } from 'wagmi';
import { createPublicClient, http, parseUnits, formatEther, erc20Abi } from 'viem';
import { useInterwovenKit } from '@initia/interwovenkit-react';

import { INIT_TOKEN, INIT_DECIMALS, DripVaultABI } from '@/lib/contracts';

interface DepositFormProps {
  vaultAddress: `0x${string}`;
}

const publicClient = createPublicClient({
  transport: http('https://jsonrpc-evm-1.anvil.asia-southeast.initia.xyz'),
});

const TARGET_CHAIN_ID = 2124225178762456;

export default function DepositForm({ vaultAddress }: DepositFormProps) {
  const { isConnected, hexAddress } = useInterwovenKit();
  const { address: wagmiAddress } = useAccount();
  const { switchChainAsync } = useSwitchChain();
  
  const address = wagmiAddress || (hexAddress as `0x${string}` | undefined);
  
  const [amount, setAmount] = useState('');
  const [allowance, setAllowance] = useState<bigint>(BigInt(0));
  const [isWorking, setIsWorking] = useState(false);
  const [statusText, setStatusText] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const [userBalance, setUserBalance] = useState<bigint>(BigInt(0));

  const { writeContractAsync } = useWriteContract();

  // Fetch current allowance + balance
  useEffect(() => {
    const fetchData = async () => {
      if (!address) return;
      try {
        const [currentAllowance, bal] = await Promise.all([
          publicClient.readContract({
            address: INIT_TOKEN as `0x${string}`,
            abi: erc20Abi,
            functionName: 'allowance',
            args: [address as `0x${string}`, vaultAddress],
          }),
          publicClient.readContract({
            address: INIT_TOKEN as `0x${string}`,
            abi: erc20Abi,
            functionName: 'balanceOf',
            args: [address as `0x${string}`],
          }),
        ]);
        setAllowance(currentAllowance as bigint);
        setUserBalance(bal as bigint);
      } catch (err) {
        console.error("Failed to fetch data", err);
      }
    };
    fetchData();
  }, [address, vaultAddress, isWorking]);

  const parsedAmount = amount ? parseUnits(amount, INIT_DECIMALS) : BigInt(0);
  const needsApproval = parsedAmount > allowance;

  const handleDeposit = async () => {
    if (!amount || parsedAmount <= BigInt(0) || !address) return;
    
    setIsWorking(true);
    setError(null);
    setSuccess(false);

    try {
      // Switch chain
      try { await switchChainAsync({ chainId: TARGET_CHAIN_ID }); } catch {}

      // STEP 1: Approval (if needed)
      if (needsApproval) {
        setStatusText('Approving INIT...');
        
        await writeContractAsync({
          address: INIT_TOKEN as `0x${string}`,
          abi: erc20Abi,
          functionName: 'approve',
          args: [vaultAddress, parsedAmount],
        });

        // Wait for indexing
        await new Promise(resolve => setTimeout(resolve, 2000));
      }

      // STEP 2: Deposit
      setStatusText('Depositing...');
      
      await writeContractAsync({
        address: vaultAddress,
        abi: DripVaultABI,
        functionName: 'deposit',
        args: [parsedAmount],
      });

      setSuccess(true);
      setAmount('');
      setStatusText('');

    } catch (err: any) {
      console.error('Deposit error:', err);
      setError(err.shortMessage || err.message || "Transaction rejected or failed");
    } finally {
      setIsWorking(false);
      setStatusText('');
    }
  };

  let buttonLabel = 'Deposit';
  if (!isConnected) buttonLabel = 'Connect Wallet';
  else if (isWorking) buttonLabel = statusText;
  else if (needsApproval) buttonLabel = 'Approve & Deposit';

  return (
    <div className="flex flex-col gap-5 pt-2">
      
      {/* Input Group */}
      <div className="flex flex-col gap-2">
        <div className="flex justify-between items-center">
          <label className="text-xs font-bold text-zinc-400 uppercase tracking-widest">
            Deposit Amount
          </label>
          <span className="text-[10px] text-zinc-500 uppercase tracking-wider">
            Balance: {Number(formatEther(userBalance)).toLocaleString('en-US', { maximumFractionDigits: 4 })} INIT
          </span>
        </div>
        
        <div className="relative flex items-center bg-black/40 border border-white/10 rounded-xl p-2 transition-all focus-within:border-blue-500 focus-within:ring-1 focus-within:ring-blue-500/50">
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
              onClick={() => setAmount(formatEther(userBalance))}
              disabled={isWorking}
              className="bg-blue-500/10 text-blue-400 hover:bg-blue-500/20 hover:text-blue-300 transition-colors text-[10px] font-bold px-2.5 py-1.5 rounded-lg uppercase tracking-wider disabled:opacity-50 disabled:cursor-not-allowed"
            >
              MAX
            </button>
            <div className="flex items-center gap-1.5 bg-white/5 px-3 py-1.5 rounded-lg border border-white/5">
              <div className="w-4 h-4 rounded-full bg-gradient-to-tr from-blue-500 to-purple-500" />
              <span className="text-sm font-semibold text-white">INIT</span>
            </div>
          </div>
        </div>
      </div>

      {/* Messages */}
      {error && (
        <div className="text-xs font-medium text-red-400 bg-red-500/10 border border-red-500/20 p-3 rounded-lg text-center">
          {error}
        </div>
      )}
      
      {success && (
        <div className="text-xs font-medium text-green-400 bg-green-500/10 border border-green-500/20 p-3 rounded-lg text-center">
          Deposit confirmed! Yield is now compounding.
        </div>
      )}

      {/* Submit Button */}
      <button 
        onClick={handleDeposit}
        disabled={!amount || parsedAmount <= BigInt(0) || isWorking || !isConnected}
        className={`w-full py-4 rounded-xl font-semibold transition-all duration-300 flex justify-center items-center gap-2 ${
          !isConnected || !amount || parsedAmount <= BigInt(0)
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