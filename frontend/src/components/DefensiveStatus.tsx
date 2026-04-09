import { getDefensiveStatusMessage } from '@/lib/oracle';

interface DefensiveStatusProps {
  statusCode: string;
  consecutiveDrops?: number;
}

export default function DefensiveStatus({ statusCode, consecutiveDrops }: DefensiveStatusProps) {
  const isSiren = statusCode === 'DEFENSIVE_MODE';
  const isStale = statusCode === 'STALE_ORACLE';

  // Configuration map for different states
  let config = {
    wrapper: 'bg-green-500/5 border-green-500/20',
    dot: 'bg-green-400 shadow-[0_0_10px_rgba(74,222,128,0.6)]',
    title: 'text-green-400',
    label: 'Auto-Compounding Active'
  };

  if (isSiren) {
    config = {
      wrapper: 'bg-red-500/5 border-red-500/20',
      dot: 'bg-red-400 shadow-[0_0_10px_rgba(248,113,113,0.6)] animate-pulse',
      title: 'text-red-400',
      label: 'Defensive Mode Engaged'
    };
  } else if (isStale) {
    config = {
      wrapper: 'bg-amber-500/5 border-amber-500/20',
      dot: 'bg-amber-400 shadow-[0_0_10px_rgba(251,191,36,0.6)] animate-pulse',
      title: 'text-amber-400',
      label: 'Oracle Warning'
    };
  }

  return (
    <div className={`flex items-start sm:items-center gap-4 p-4 md:p-5 rounded-2xl border backdrop-blur-md transition-colors duration-300 ${config.wrapper}`}>
      
      {/* Glowing Status Dot */}
      <div className="shrink-0 mt-1 sm:mt-0 flex items-center justify-center w-6 h-6 rounded-full bg-black/20 border border-white/5">
        <span className={`block w-2.5 h-2.5 rounded-full ${config.dot}`} />
      </div>
      
      {/* Text Content */}
      <div className="flex flex-col">
        <span className={`text-[10px] font-bold uppercase tracking-widest mb-0.5 ${config.title}`}>
          {config.label}
        </span>
        <span className="text-sm md:text-base font-medium text-zinc-300 leading-snug">
          {getDefensiveStatusMessage(statusCode, consecutiveDrops)}
        </span>
      </div>

    </div>
  );
}