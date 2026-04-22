import CreateVaultForm from '@/components/CreateVaultForm';

export default function CreatePage() {
  return (
    <main className="min-h-screen bg-gradient-to-b from-[#0d0520] via-[#080312] to-[#050505] pt-12 pb-24 relative overflow-hidden">
      
      {/* ── Ambient Purple Glow ── */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full max-w-3xl h-64 bg-gradient-to-b from-purple-500/15 to-transparent blur-[100px] pointer-events-none" />
      <div className="absolute bottom-0 right-0 w-[400px] h-[300px] bg-fuchsia-700/8 rounded-full blur-[120px] pointer-events-none" />

      <div className="max-w-7xl mx-auto px-6 relative z-10 flex flex-col items-center">
        
        {/* ── Page Header ── */}
        <div className="flex flex-col items-center text-center gap-4 mb-12 mt-4">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full border border-blue-500/20 bg-blue-500/10">
            <span className="w-2 h-2 rounded-full bg-blue-400 shadow-[0_0_8px_rgba(59,130,246,0.8)]" />
            <span className="text-[10px] font-bold text-blue-300 uppercase tracking-widest">
              Vault Factory
            </span>
          </div>
          
          <h1 className="text-5xl md:text-6xl font-serif font-medium text-white tracking-tight">
            Deploy a Vault
          </h1>
          
          <p className="text-lg text-zinc-400 max-w-xl leading-relaxed">
            Create your own customized Drip strategy, invite depositors, and earn performance fees entirely on-chain.
          </p>
        </div>

        {/* ── Form Container ── */}
        {/* The CreateVaultForm component already has max-w-2xl and mx-auto, so we just pass it full width here */}
        <div className="w-full">
          <CreateVaultForm />
        </div>

      </div>
    </main>
  );
}