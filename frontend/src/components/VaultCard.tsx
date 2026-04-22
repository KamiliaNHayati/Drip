import Link from 'next/link';

interface VaultCardProps {
  address: string;
  name: string;
  creator: string;
  tvl: string;
  apy: string;
  isNew?: boolean;
}

export default function VaultCard({ address, name, creator, tvl, apy, isNew }: VaultCardProps) {
  
  // Smart truncate: only truncate if it's a raw address, leave .init names alone
  const displayCreator = creator?.endsWith('.init') 
    ? creator 
    : creator ? `${creator.slice(0, 6)}...${creator.slice(-4)}` : 'Unknown';

  return (
    <div className="relative bg-[#0a0a0e]/80 backdrop-blur-xl border border-white/10 rounded-3xl p-6 flex flex-col transition-all duration-300 hover:-translate-y-1 hover:border-blue-500/40 hover:shadow-[0_8px_30px_rgba(59,130,246,0.15)] group overflow-hidden">
      
      {/* Subtle background glow on hover */}
      <div className="absolute inset-0 bg-gradient-to-br from-blue-500/0 to-purple-500/0 group-hover:from-blue-500/5 group-hover:to-purple-500/5 transition-colors duration-500 pointer-events-none" />

      {/* ── Header ── */}
      <div className="relative z-10 flex justify-between items-start mb-6">
        <div className="flex flex-col">
          <h3 className="font-serif text-2xl font-medium text-white mb-1 tracking-tight drop-shadow-md">
            {name}
          </h3>
          <span className="text-sm font-medium text-zinc-500">
            by <span className="text-zinc-300">{displayCreator}</span>
          </span>
        </div>
        
        {isNew && (
          <span className="shrink-0 bg-blue-500/10 border border-blue-500/20 text-blue-400 text-[10px] font-bold uppercase tracking-wider px-2.5 py-1 rounded-lg">
            New
          </span>
        )}
      </div>
      
      {/* ── Stats ── */}
      <div className="relative z-10 flex items-center justify-between bg-black/40 border border-white/5 rounded-2xl p-4 mb-6">
        <div className="flex flex-col gap-1">
          <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">
            TVL
          </span>
          <div className="flex items-baseline gap-1">
            <span className="font-mono text-lg sm:text-xl font-semibold text-white tracking-tight">{tvl}</span>
            <span className="text-[10px] sm:text-xs text-zinc-500 font-medium">INIT</span>
          </div>
        </div>
        
        {/* Vertical Divider */}
        <div className="w-px h-10 bg-white/10" />

        <div className="flex flex-col gap-1 text-right">
          <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">
            Base APY
          </span>
          <span className="font-mono text-xl sm:text-2xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-purple-500 tracking-tight">
            {apy}%
          </span>
        </div>
      </div>
      
      {/* ── CTA ── */}
      <Link 
        href={`/vault/${address}`} 
        className="relative z-10 mt-auto w-full py-3.5 rounded-xl border border-white/10 bg-white/5 text-sm font-semibold text-zinc-300 text-center transition-all duration-300 hover:bg-white/10 hover:text-white hover:border-white/20"
      >
        Enter Vault
      </Link>
    </div>
  );
}