'use client';

import { useParams } from 'next/navigation';
import CompetitionPanel from '@/components/CompetitionPanel';
import Leaderboard from '@/components/Leaderboard';

export default function CompetitionPage() {
  const params = useParams();
  const id = params.id as string;

  // Mock data for UI development
  const mockCompetition = {
    id: id || '1',
    status: 'active' as const,
    endTime: '2d 14h 30m',
    participantCount: 3, // PRD rule: show participant count, NOT raw INIT prize pool
    entryFee: '1000000000000000000', // 1 INIT
    isEntered: false,
    canSettle: false,
    participants: [
      { address: '0x1234567890abcdef1234567890abcdef12345678', growthBps: 1250 }, // +12.5%
      { address: '0x9876543210abcdef1234567890abcdef12345678', growthBps: 840 },  // +8.4%
      { address: '0x5555555555abcdef1234567890abcdef12345678', growthBps: -420 }, // -4.2%
    ]
  };

  return (
    <main className="min-h-screen bg-gradient-to-b from-[#0d0520] via-[#080312] to-[#050505] pt-12 pb-24 relative overflow-hidden">
      
      {/* ── Ambient Purple Glow ── */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full max-w-4xl h-64 bg-gradient-to-b from-purple-500/15 to-transparent blur-[100px] pointer-events-none" />
      <div className="absolute bottom-0 right-0 w-[400px] h-[300px] bg-fuchsia-700/8 rounded-full blur-[120px] pointer-events-none" />

      <div className="max-w-7xl mx-auto px-6 relative z-10">
        
        {/* ── Page Header ── */}
        <div className="flex flex-col items-center text-center gap-4 mb-16">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full border border-blue-500/20 bg-blue-500/10">
            <span className="w-2 h-2 rounded-full bg-blue-400 shadow-[0_0_8px_rgba(59,130,246,0.8)] animate-pulse" />
            <span className="text-[10px] font-bold text-blue-300 uppercase tracking-widest">
              Epoch {mockCompetition.id} Live
            </span>
          </div>
          
          <h1 className="text-5xl md:text-6xl font-serif font-medium text-white tracking-tight">
            Global Yield Race
          </h1>
          
          <p className="text-lg text-zinc-400 max-w-2xl leading-relaxed">
            Put your vault's strategy to the test. The highest Price-Per-Share (PPS) growth at the end of the epoch wins the entire pool.
          </p>
        </div>

        {/* ── Main Layout Grid ── */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
          
          {/* Left Column: Leaderboard (Takes up 8/12 cols on desktop) */}
          <div className="lg:col-span-8 flex flex-col gap-6">
            <Leaderboard participants={mockCompetition.participants} />
          </div>
          
          {/* Right Column: Panel & Actions (Takes up 4/12 cols on desktop) */}
          <div className="lg:col-span-4 sticky top-32">
            <CompetitionPanel 
              status={mockCompetition.status}
              endTime={mockCompetition.endTime}
              participantCount={mockCompetition.participantCount}
              leaderboard={mockCompetition.participants.map(p => ({
                address: p.address,
                username: null,
                growthBps: p.growthBps,
              }))}
            />
          </div>

        </div>

      </div>
    </main>
  );
}