'use client';

import { useState } from 'react';
import { createPortal } from 'react-dom';
import BattleCard from '@/components/BattleCard';

export default function BattlesPage() {
  const [activeTab, setActiveTab] = useState<'active' | 'history'>('active');
  const [isDeclaring, setIsDeclaring] = useState(false);

  const modal = isDeclaring && typeof document !== 'undefined' ? createPortal(
    <div 
      className="fixed inset-0 z-[9999] flex items-center justify-center p-6 bg-black/80 backdrop-blur-md"
      onClick={() => setIsDeclaring(false)}
    >
      <div 
        className="w-full max-w-md bg-[#0a0a0e] border border-white/10 rounded-3xl p-8 shadow-2xl relative max-h-[85vh] overflow-y-auto" 
        onClick={e => e.stopPropagation()}
      >
        
        {/* Modal Header */}
        <div className="flex justify-between items-center mb-8">
          <h2 className="text-2xl font-serif font-medium text-white tracking-tight">Issue Challenge</h2>
          <button 
            onClick={() => setIsDeclaring(false)}
            className="w-8 h-8 flex items-center justify-center rounded-full bg-white/5 text-zinc-400 hover:text-white hover:bg-white/10 transition-colors"
          >
            ✕
          </button>
        </div>

        {/* Modal Body */}
        <div className="flex flex-col gap-5">
          
          <div className="flex flex-col gap-2">
            <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Defender Vault Address</label>
            <input 
              type="text" 
              placeholder="0x..." 
              className="w-full bg-black/50 border border-white/10 focus:border-purple-500 focus:ring-1 focus:ring-purple-500/50 rounded-xl px-4 py-3 text-white placeholder:text-zinc-600 transition-all outline-none font-mono text-sm"
            />
          </div>

          <div className="flex flex-col gap-2">
            <div className="flex justify-between items-center">
              <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Wager Amount</label>
              <span className="text-[10px] text-zinc-500 uppercase tracking-wider">Min 10 INIT</span>
            </div>
            <div className="relative flex items-center bg-black/50 border border-white/10 rounded-xl p-1.5 transition-all focus-within:border-purple-500 focus-within:ring-1 focus-within:ring-purple-500/50">
              <input 
                type="number" 
                placeholder="0.0" 
                className="w-full bg-transparent outline-none text-white text-lg font-mono px-3 placeholder:text-zinc-600"
              />
              <div className="flex items-center gap-1.5 bg-white/5 px-3 py-1.5 rounded-lg border border-white/5 shrink-0">
                <span className="text-xs font-semibold text-white">INIT</span>
              </div>
            </div>
          </div>

          <div className="flex flex-col gap-2 mb-2">
            <label className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Duration (Hours)</label>
            <input 
              type="number" 
              defaultValue="48" 
              className="w-full bg-black/50 border border-white/10 focus:border-purple-500 focus:ring-1 focus:ring-purple-500/50 rounded-xl px-4 py-3 text-white placeholder:text-zinc-600 transition-all outline-none font-mono text-sm"
            />
          </div>

          {/* Protocol Fees Warning */}
          <div className="p-4 bg-purple-500/5 border border-purple-500/20 rounded-xl flex flex-col gap-1">
            <div className="flex justify-between items-center">
              <span className="text-xs text-zinc-400">Protocol Challenge Fee</span>
              <span className="text-xs font-mono text-white">40 INIT</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-xs text-zinc-400">Total Upfront Cost</span>
              <span className="text-xs font-mono font-bold text-purple-400">Wager + 40 INIT</span>
            </div>
          </div>

          <button className="w-full py-4 rounded-xl font-semibold bg-white text-black hover:bg-zinc-200 transition-all duration-300 shadow-[0_4px_20px_rgba(255,255,255,0.15)] flex justify-center items-center gap-2 mt-2">
            Send Challenge ⚔️
          </button>

        </div>
      </div>
    </div>,
    document.body
  ) : null;

  return (
    <>
    <main className="min-h-screen bg-gradient-to-b from-[#0d0520] via-[#080312] to-[#050505] pt-12 pb-24 relative overflow-hidden">
      
      {/* Ambient purple glow */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full max-w-3xl h-64 bg-gradient-to-b from-purple-500/15 to-transparent blur-[100px] pointer-events-none" />
      <div className="absolute bottom-0 right-0 w-[400px] h-[300px] bg-fuchsia-700/8 rounded-full blur-[120px] pointer-events-none" />

      <div className="max-w-7xl mx-auto px-6 relative z-10">
        
        {/* ── Header ─────────────────────────────────────────── */}
        <div className="flex flex-col md:flex-row justify-between items-start md:items-end gap-6 mb-12">
          <div className="flex flex-col gap-4">
            <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full border border-purple-500/20 bg-purple-500/10 self-start">
              <span className="w-2 h-2 rounded-full bg-purple-400 shadow-[0_0_8px_rgba(168,85,247,0.8)] animate-pulse" />
              <span className="text-[10px] font-bold text-purple-300 uppercase tracking-widest">PvP Arena</span>
            </div>
            <h1 className="text-5xl md:text-6xl font-serif font-medium text-white tracking-tight">
              Yield Battles
            </h1>
            <p className="text-lg text-zinc-400 max-w-xl leading-relaxed">
              Declare 1v1 wars against rival vaults. The vault with the highest PPS growth takes 80% of the combined wager.
            </p>
          </div>
          
          <button 
            onClick={() => setIsDeclaring(true)}
            className="bg-white text-black font-semibold px-8 py-3.5 rounded-full hover:bg-zinc-200 transition-all shadow-[0_0_20px_rgba(255,255,255,0.1)] hover:shadow-[0_4px_25px_rgba(255,255,255,0.2)] hover:-translate-y-0.5 flex items-center gap-2 shrink-0"
          >
            Declare Battle ⚔️
          </button>
        </div>

        {/* ── Tabs ───────────────────────────────────────────── */}
        <div className="flex gap-2 p-1.5 bg-white/5 border border-white/10 rounded-2xl w-max mb-8 backdrop-blur-md">
          <button 
            className={`px-6 py-2.5 rounded-xl text-sm font-medium transition-all duration-300 ${
              activeTab === 'active' 
                ? 'bg-white/10 text-white shadow-sm' 
                : 'text-zinc-500 hover:text-zinc-300 hover:bg-white/5'
            }`}
            onClick={() => setActiveTab('active')}
          >
            Active & Pending
          </button>
          <button 
            className={`px-6 py-2.5 rounded-xl text-sm font-medium transition-all duration-300 ${
              activeTab === 'history' 
                ? 'bg-white/10 text-white shadow-sm' 
                : 'text-zinc-500 hover:text-zinc-300 hover:bg-white/5'
            }`}
            onClick={() => setActiveTab('history')}
          >
            History
          </button>
        </div>

        {/* ── Content ────────────────────────────────────────── */}
        {activeTab === 'active' ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <BattleCard 
              id="1" 
              challengerName="Yield Kings" 
              defenderName="Mewtopia" 
              wager="100" 
              endTime="12h 45m" 
            />
            <BattleCard 
              id="2" 
              challengerName="Degen Spartans" 
              defenderName="Initia Whales" 
              wager="500" 
              endTime="2d 14h" 
            />
            <BattleCard 
              id="3" 
              challengerName="Steady Lads" 
              defenderName="Curve Maxis" 
              wager="250" 
              endTime="Pending Accept..." 
            />
          </div>
        ) : (
          <div className="w-full py-24 bg-white/5 border border-white/10 border-dashed rounded-3xl flex flex-col items-center justify-center gap-3">
             <span className="text-4xl">🪦</span>
             <span className="text-zinc-500 text-sm font-medium">No recent battles found in your history.</span>
          </div>
        )}

      </div>
    </main>
    {modal}
    </>
  );
}