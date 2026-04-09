'use client';

import { useState, useRef, useEffect } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useInterwovenKit } from '@initia/interwovenkit-react';

export default function ConnectButton() {
  const { isConnected, hexAddress, username, openConnect, disconnect } = useInterwovenKit();
  
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  
  // Bring in Next.js routing hooks
  const pathname = usePathname();
  const router = useRouter();

  // Helper to format the EVM address cleanly
  const truncateAddress = (addr: string) => {
    if (!addr) return '';
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };

  // Close dropdown when clicking outside
  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setDropdownOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // ─── Smart Disconnect Logic ─────────────────────────────────────────
  const handleDisconnect = () => {
    disconnect();
    setDropdownOpen(false);
    
    // List of routes that require a connected wallet
    const protectedRoutes = ['/create', '/battles', '/squads', '/ghosts'];
    
    // If they disconnect while on a protected route, route them to the home page
    if (protectedRoutes.some(route => pathname.startsWith(route))) {
      router.push('/');
    }
  };

  // Determine what to show: Username if it exists, otherwise truncated hex address
  const displayName = username || truncateAddress(hexAddress);

  // ─── CONNECTED STATE ────────────────────────────────────────────────
  if (isConnected && hexAddress) {
    return (
      <div className="relative" ref={ref}>
        <button
          className="flex items-center gap-2.5 bg-white/5 border border-white/10 hover:bg-white/10 hover:border-white/20 px-5 py-2.5 rounded-full transition-all duration-300"
          onClick={() => setDropdownOpen(!dropdownOpen)}
        >
          {/* Glowing Green Dot */}
          <span className="w-2 h-2 rounded-full bg-green-400 shadow-[0_0_8px_rgba(74,222,128,0.6)] animate-pulse" />
          
          {/* Display Name / Monospace Address */}
          <span className={`text-sm font-medium text-white tracking-wide ${!username ? 'font-mono' : 'font-sans'}`}>
            {displayName}
          </span>
          
          {/* Chevron */}
          <svg 
            className={`w-4 h-4 text-zinc-400 transition-transform duration-300 ${dropdownOpen ? 'rotate-180' : ''}`} 
            fill="none" 
            stroke="currentColor" 
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        </button>

        {/* Dropdown Menu */}
        {dropdownOpen && (
          <div className="absolute right-0 top-[calc(100%+0.5rem)] w-48 bg-[#0a0a0e]/95 backdrop-blur-xl border border-white/10 rounded-2xl p-2 shadow-[0_10px_40px_rgba(0,0,0,0.8)] z-50 animate-in fade-in slide-in-from-top-2 duration-200">
            <div className="flex flex-col gap-1">
              <Link 
                href="/create" 
                className="px-3 py-2.5 text-sm font-medium text-zinc-300 hover:text-white hover:bg-white/10 rounded-xl transition-colors"
                onClick={() => setDropdownOpen(false)}
              >
                Create Vault
              </Link>
              <Link 
                href="/battles" 
                className="px-3 py-2.5 text-sm font-medium text-zinc-300 hover:text-white hover:bg-white/10 rounded-xl transition-colors"
                onClick={() => setDropdownOpen(false)}
              >
                My Battles
              </Link>
              <Link 
                href="/squads" 
                className="px-3 py-2.5 text-sm font-medium text-zinc-300 hover:text-white hover:bg-white/10 rounded-xl transition-colors"
                onClick={() => setDropdownOpen(false)}
              >
                My Squad
              </Link>
              
              {/* Divider */}
              <div className="h-[1px] bg-white/10 my-1 mx-2" />
              
              <button 
                className="w-full text-left px-3 py-2.5 text-sm font-medium text-red-400 hover:text-red-300 hover:bg-red-500/10 rounded-xl transition-colors"
                onClick={handleDisconnect}
              >
                Disconnect
              </button>
            </div>
          </div>
        )}
      </div>
    );
  }

  // ─── DISCONNECTED STATE ─────────────────────────────────────────────
  return (
    <div className="flex flex-col items-center">
      <button 
        className="bg-white text-black font-semibold px-8 py-3 rounded-full transition-all duration-300 hover:bg-zinc-200 shadow-[0_4px_20px_rgba(255,255,255,0.15)] hover:shadow-[0_6px_25px_rgba(255,255,255,0.25)] hover:-translate-y-0.5"
        onClick={() => openConnect()}
      >
        Connect Wallet
      </button>
    </div>
  );
}