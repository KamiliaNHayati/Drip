import Link from 'next/link';

interface BattleCardProps {
  id: string;
  challengerName: string;
  defenderName: string;
  wager: string;
  endTime: string;
}

export default function BattleCard({ id, challengerName, defenderName, wager, endTime }: BattleCardProps) {
  return (
    <div className="relative bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-2xl p-6 flex flex-col gap-6 transition-all duration-300 hover:-translate-y-1 hover:border-purple-500/40 hover:shadow-[0_8px_30px_rgba(124,58,237,0.15)] group overflow-hidden">
      
      {/* Subtle split background gradient that glows on hover */}
      <div className="absolute inset-0 bg-gradient-to-r from-blue-500/0 via-transparent to-purple-500/0 group-hover:from-blue-500/5 group-hover:to-purple-500/5 transition-colors duration-500 pointer-events-none" />

      {/* Teams Row */}
      <div className="relative z-10 flex items-center justify-between pb-5 border-b border-white/5">
        <div className="flex-1 text-center">
          <span className="block font-serif text-xl font-medium text-white truncate px-2 drop-shadow-md">
            {challengerName}
          </span>
        </div>
        
        <div className="shrink-0 px-3">
          <span className="text-xl font-black italic tracking-wider text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-purple-500 drop-shadow-sm">
            VS
          </span>
        </div>
        
        <div className="flex-1 text-center">
          <span className="block font-serif text-xl font-medium text-white truncate px-2 drop-shadow-md">
            {defenderName}
          </span>
        </div>
      </div>
      
      {/* Stats Row */}
      <div className="relative z-10 flex justify-between items-center">
        <div className="flex flex-col gap-1">
          <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Combined Wager</span>
          <div className="flex items-baseline gap-1">
            <span className="text-xl font-semibold text-white">{wager}</span>
            <span className="text-xs text-zinc-400 font-medium">INIT</span>
          </div>
        </div>
        <div className="flex flex-col gap-1 text-right">
          <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Ends In</span>
          <span className="text-lg font-medium text-blue-400">{endTime}</span>
        </div>
      </div>
      
      {/* CTA Button */}
      <Link 
        href={`/battles`} 
        className="relative z-10 w-full py-3 rounded-full border border-white/10 bg-white/5 text-sm font-medium text-zinc-300 text-center transition-all duration-300 hover:bg-white/10 hover:text-white hover:border-white/20"
      >
        View Battle
      </Link>
    </div>
  );
}