'use client';

import { useEffect, useState, useMemo } from 'react';
import { resolveInitNames } from '@/lib/naming';

interface Participant {
  address: string;
  growthBps: number;
}

interface LeaderboardProps {
  participants: Participant[];
}

export default function Leaderboard({ participants }: LeaderboardProps) {
  const [nameMap, setNameMap] = useState<Record<string, string>>({});
  
  // Memoize the sorted array so it doesn't re-sort on every render
  const sorted = useMemo(() => {
    return [...participants].sort((a, b) => b.growthBps - a.growthBps);
  }, [participants]);

  // Fetch .init names safely and map them to their addresses
  useEffect(() => {
    async function fetchNames() {
      if (sorted.length === 0) return;
      
      const addresses = sorted.map(p => p.address);
      const resolved = await resolveInitNames(addresses);
      
      const newNameMap: Record<string, string> = {};
      addresses.forEach((addr, i) => {
        if (resolved[i]) {
          newNameMap[addr] = resolved[i];
        }
      });
      setNameMap(newNameMap);
    }
    fetchNames();
  }, [sorted]);

  const truncateAddress = (addr: string) => `${addr.slice(0, 6)}...${addr.slice(-4)}`;

  return (
    <div className="bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-3xl p-6 md:p-8 shadow-2xl flex flex-col">
      <h3 className="text-2xl font-serif font-medium text-white mb-6">Live Rankings</h3>
      
      <div className="flex flex-col">
        {/* ── Table Header ── */}
        <div className="grid grid-cols-[60px_1fr_90px] px-4 py-3 text-[10px] font-bold text-zinc-500 uppercase tracking-widest border-b border-white/10 mb-2">
          <span>Rank</span>
          <span>Vault</span>
          <span className="text-right">PPS Growth</span>
        </div>

        {/* ── Empty State ── */}
        {sorted.length === 0 && (
          <div className="py-12 text-center flex flex-col items-center gap-2">
            <span className="text-3xl">👻</span>
            <span className="text-zinc-500 text-sm font-medium">No participants yet.</span>
          </div>
        )}

        {/* ── Table Rows ── */}
        <div className="flex flex-col gap-1">
          {sorted.map((p, i) => {
            const isFirst = i === 0;
            const displayName = nameMap[p.address] || truncateAddress(p.address);
            const isPositive = p.growthBps > 0;
            const isNegative = p.growthBps < 0;
            const growthStr = `${isPositive ? '+' : ''}${(p.growthBps / 100).toFixed(2)}%`;

            return (
              <div 
                key={p.address} 
                className={`grid grid-cols-[60px_1fr_90px] items-center px-4 py-3.5 rounded-xl transition-colors ${
                  isFirst 
                    ? 'bg-blue-500/10 border border-blue-500/20 relative overflow-hidden' 
                    : 'hover:bg-white/5 border border-transparent'
                }`}
              >
                {/* Background glow for 1st place */}
                {isFirst && (
                  <div className="absolute top-0 left-0 w-1/2 h-full bg-gradient-to-r from-blue-400/10 to-transparent pointer-events-none" />
                )}

                {/* Rank */}
                <span className={`relative z-10 font-serif text-lg font-bold ${
                  isFirst ? 'text-amber-400 drop-shadow-[0_0_8px_rgba(251,191,36,0.5)]' : 'text-zinc-500'
                }`}>
                  #{i + 1}
                </span>

                {/* Name */}
                <span className={`relative z-10 font-medium truncate pr-2 ${
                  isFirst ? 'text-white' : 'text-zinc-300'
                }`}>
                  {displayName}
                </span>

                {/* Growth (Monospace for perfect decimal alignment) */}
                <span className={`relative z-10 font-mono text-sm sm:text-base font-medium text-right ${
                  isPositive ? 'text-green-400' : isNegative ? 'text-red-400' : 'text-zinc-500'
                }`}>
                  {growthStr}
                </span>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}