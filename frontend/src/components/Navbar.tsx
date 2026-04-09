'use client';

import Link from 'next/link';
import { useInterwovenKit } from '@initia/interwovenkit-react';
import ConnectButton from './ConnectButton';
import Image from 'next/image';

export default function Navbar() {
  const { isConnected } = useInterwovenKit();

  return (
    <nav className="sticky top-0 z-50 bg-[#050505]/80 backdrop-blur-2xl border-b border-white/5 transition-all duration-300">
      <div className="max-w-7xl mx-auto px-6 h-24 flex items-center justify-between relative">
        
        {/* ── Logo ── */}
        <Link href="/" className="flex items-center gap-2 group shrink-0">
        <Image 
          src="/logo(1).svg" 
          alt="Drip Logo" 
          width={32} 
          height={32} 
          loading="eager"
          className="transition-transform group-hover:scale-110 duration-300 drop-shadow-[0_0_10px_rgba(59,130,246,0.5)]"
        />
          <span className="text-2xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-purple-500 font-serif tracking-tight">
            Drip
          </span>
        </Link>

        {/* ── Links (Absolute Centered on Desktop) ── */}
        <div className="hidden lg:flex items-center gap-8 absolute left-1/2 -translate-x-1/2">
          <Link href="/" className="text-sm font-medium text-zinc-400 hover:text-white transition-colors">
            Explore
          </Link>
          
          {/* Only show interactive protocol features if wallet is connected */}
          {isConnected && (
            <>
              <Link href="/battles" className="text-sm font-medium text-zinc-400 hover:text-white transition-colors">
                Battles
              </Link>
              <Link href="/borrow" className="text-sm font-medium text-zinc-400 hover:text-white transition-colors">
                Borrow
              </Link>
              <Link href="/squads" className="text-sm font-medium text-zinc-400 hover:text-white transition-colors">
                Squads
              </Link>
              <Link href="/ghosts" className="text-sm font-medium text-zinc-400 hover:text-white transition-colors">
                Ghosts
              </Link>
            </>
          )}
          
          <Link href="/docs" className="text-sm font-medium text-zinc-400 hover:text-white transition-colors">
            Docs
          </Link>
        </div>

        {/* ── Connect Button ── */}
        <div className="shrink-0 flex items-center">
          <ConnectButton />
        </div>
        
      </div>
    </nav>
  );
}