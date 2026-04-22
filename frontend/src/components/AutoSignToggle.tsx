'use client';
import { useState } from 'react';

export default function AutoSignToggle() {
  const [enabled, setEnabled] = useState(false);
  const [loading, setLoading] = useState(false);

  const toggle = () => {
    setLoading(true);
    // Mock AuthZ
    setTimeout(() => {
      setEnabled(!enabled);
      setLoading(false);
    }, 1000);
  };

  return (
    <div 
      className={`relative overflow-hidden mt-6 rounded-2xl border transition-colors duration-500 p-6 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-6 ${
        enabled 
          ? 'bg-[#0a0a0e] border-purple-500/30 shadow-[0_0_30px_rgba(124,58,237,0.1)]' 
          : 'bg-black/40 backdrop-blur-md border-white/10'
      }`}
    >
      {/* Subtle animated gradient background when enabled */}
      {enabled && (
        <div className="absolute inset-0 bg-gradient-to-r from-blue-500/10 to-purple-500/10 pointer-events-none opacity-50" />
      )}

      <div className="relative z-10 flex-1">
        <div className="flex items-center gap-3 mb-2">
          {/* Glowing Status Indicator */}
          <span className={`w-2 h-2 rounded-full transition-colors duration-300 ${
            enabled 
              ? 'bg-green-400 shadow-[0_0_10px_rgba(74,222,128,0.6)]' 
              : 'bg-zinc-600'
          }`} />
          <h4 className="text-xl font-serif font-medium text-white m-0 tracking-tight">
            AutoSign Execution
          </h4>
        </div>
        <p className="text-sm text-zinc-400 leading-relaxed max-w-md m-0">
          Approve ghost wallets to securely harvest and reinvest your yield 24/7. Zero gas fees, zero manual transactions.
        </p>
      </div>

      <button 
        onClick={toggle}
        disabled={loading}
        className={`relative z-10 shrink-0 px-7 py-3 rounded-full font-medium transition-all duration-300 flex items-center justify-center min-w-[160px] ${
          enabled 
            ? 'bg-white/5 border border-white/10 text-zinc-300 hover:bg-white/10 hover:text-white' 
            : 'bg-white text-black hover:bg-zinc-200 shadow-[0_4px_20px_rgba(255,255,255,0.15)] hover:shadow-[0_6px_25px_rgba(255,255,255,0.25)]'
        }`}
      >
        {loading ? (
          <span className="flex items-center gap-2">
            <svg className="animate-spin h-4 w-4 text-current" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            Processing...
          </span>
        ) : enabled ? 'Revoke AutoSign' : 'Enable AutoSign'}
      </button>
    </div>
  );
}