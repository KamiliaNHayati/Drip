'use client';

import React from 'react';

// Mock data types
interface Participant {
  address: string;
  username: string | null;
  growthBps: number; // e.g., 420 = 4.20%
}

interface CompetitionPanelProps {
  id?: string;           // add
  entryFee?: string;     // add
  isEntered?: boolean;   // add
  canSettle?: boolean;   // add
  status: 'active' | 'upcoming' | 'settled';
  participantCount: number;
  endTime: string;
  leaderboard: Participant[];
  currentUserAddress?: string;
}

export default function CompetitionPanel({ 
  id,
  entryFee,
  isEntered,
  canSettle,
  status, 
  participantCount, 
  endTime, 
  leaderboard,
  currentUserAddress = '0x1234567890abcdef'
}: CompetitionPanelProps) {
  
  // Format BPS to percentage (e.g., 425 -> "+4.25%")
  const formatGrowth = (bps: number) => {
    const pct = (bps / 100).toFixed(2);
    return bps > 0 ? `+${pct}%` : `${pct}%`;
  };

  // Status Badge Styling
  const getStatusConfig = () => {
    switch (status) {
      case 'active':
        return {
          label: 'Live Now',
          classes: 'bg-green-500/10 text-green-400 border-green-500/20',
          dot: 'bg-green-400 shadow-[0_0_8px_rgba(74,222,128,0.8)] animate-pulse'
        };
      case 'upcoming':
        return {
          label: 'Upcoming',
          classes: 'bg-blue-500/10 text-blue-400 border-blue-500/20',
          dot: 'bg-blue-400'
        };
      case 'settled':
        return {
          label: 'Settled',
          classes: 'bg-white/5 text-zinc-400 border-white/10',
          dot: 'bg-zinc-500'
        };
    }
  };

  const statusConfig = getStatusConfig();

  return (
    <div className="bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-3xl p-6 md:p-8 flex flex-col gap-8 shadow-2xl">
      
      {/* ── Panel Header ───────────────────────────────────── */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <h2 className="text-3xl font-serif font-medium text-white tracking-tight m-0">
          Epoch 14 Challenge
        </h2>
        <div className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-full border ${statusConfig.classes}`}>
          <span className={`w-2 h-2 rounded-full ${statusConfig.dot}`} />
          <span className="text-xs font-bold uppercase tracking-widest">{statusConfig.label}</span>
        </div>
      </div>

      {/* ── Panel Stats ────────────────────────────────────── */}
      <div className="grid grid-cols-2 gap-4 bg-black/40 rounded-2xl p-5 border border-white/5">
        <div className="flex flex-col gap-1">
          <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Prize Pool Status</span>
          <span className="text-xl sm:text-2xl font-semibold text-white">
            {participantCount} <span className="text-sm font-medium text-zinc-400">Competing</span>
          </span>
        </div>
        <div className="flex flex-col gap-1 text-right">
          <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">
            {status === 'settled' ? 'Ended At' : 'Ends In'}
          </span>
          <span className="text-xl sm:text-2xl font-semibold text-blue-400">
            {endTime}
          </span>
        </div>
      </div>

      {/* ── Leaderboard ────────────────────────────────────── */}
      <div className="flex flex-col">
        <h3 className="text-xl font-serif font-medium text-white mb-4">Leaderboard</h3>
        
        <div className="flex flex-col">
          {/* Table Header */}
          <div className="grid grid-cols-[60px_1fr_90px] px-4 py-3 text-[10px] font-bold text-zinc-500 uppercase tracking-widest border-b border-white/10 mb-2">
            <span>Rank</span>
            <span>Participant</span>
            <span className="text-right">Growth</span>
          </div>

          {/* Table Rows */}
          {leaderboard.length === 0 ? (
            <div className="py-12 text-center text-zinc-500 text-sm">
              No participants yet. Be the first to enter!
            </div>
          ) : (
            <div className="flex flex-col gap-1">
              {leaderboard.map((participant, index) => {
                const isFirst = index === 0;
                const isMe = participant.address === currentUserAddress;
                const growthStr = formatGrowth(participant.growthBps);
                const isPositive = participant.growthBps > 0;

                return (
                  <div 
                    key={participant.address}
                    className={`grid grid-cols-[60px_1fr_90px] items-center px-4 py-3.5 rounded-xl transition-colors ${
                      isFirst 
                        ? 'bg-blue-500/10 border border-blue-500/20 relative overflow-hidden' 
                        : 'hover:bg-white/5 border border-transparent'
                    }`}
                  >
                    {/* Rank */}
                    <span className={`font-serif text-lg font-bold ${isFirst ? 'text-amber-400 drop-shadow-[0_0_8px_rgba(251,191,36,0.5)]' : 'text-zinc-500'}`}>
                      #{index + 1}
                    </span>

                    {/* Participant Info */}
                    <div className="flex items-center gap-2 overflow-hidden">
                      <span className={`font-medium truncate ${isFirst ? 'text-white' : 'text-zinc-300'}`}>
                        {participant.username ?? `${participant.address.slice(0,6)}...${participant.address.slice(-4)}`}
                      </span>
                      {isMe && (
                        <span className="shrink-0 bg-white/10 text-white text-[9px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-md">
                          You
                        </span>
                      )}
                    </div>

                    {/* Growth */}
                    <span className={`font-mono text-sm sm:text-base font-medium text-right ${
                      isPositive ? 'text-green-400' : 'text-zinc-500'
                    }`}>
                      {growthStr}
                    </span>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* ── Actions / Alerts ───────────────────────────────── */}
      {status === 'active' && (
        <button className="w-full mt-2 py-4 rounded-xl font-medium text-black bg-white hover:bg-zinc-200 transition-colors shadow-[0_4px_20px_rgba(255,255,255,0.15)] flex justify-center items-center gap-2">
          Enter Competition
          <span className="text-zinc-500 text-sm font-normal border-l border-zinc-300 pl-2 ml-1">7 INIT</span>
        </button>
      )}

      {status === 'settled' && (
        <div className="mt-2 py-4 bg-white/5 border border-white/10 rounded-xl text-center text-zinc-400 text-sm">
          This competition has concluded. <span className="text-white font-medium">Yield Kings</span> won the prize pool.
        </div>
      )}
      
    </div>
  );
}