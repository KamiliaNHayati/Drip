import Link from 'next/link';
import Image from 'next/image';

export default function Footer() {
  return (
    <footer className="bg-gradient-to-b from-[#050505] to-[#07041a] border-t border-purple-500/10 relative overflow-hidden">
      
      {/* Subtle ambient purple glow at the bottom */}
      <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-3/4 h-32 bg-gradient-to-t from-purple-500/5 to-transparent blur-[80px] pointer-events-none" />
      
      <div className="max-w-5xl mx-auto px-6 pt-16 pb-8 flex flex-col items-center gap-10 relative z-10">
        
        {/* Brand & Tagline */}
        <div className="flex flex-col items-center gap-2">
          <Link href="/" className="flex items-center gap-2">
            <Image 
              src="/logo(1).svg" 
              alt="Drip Logo" 
              width={32} 
              height={32} 
              className="transition-transform group-hover:scale-110 duration-300 drop-shadow-[0_0_10px_rgba(59,130,246,0.5)]"
            />
            <span className="font-serif text-2xl font-bold tracking-tight text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-purple-500">
              Drip
            </span>
          </Link>
          <p className="text-sm font-medium text-zinc-500">
            Social yield on Initia
          </p>
        </div>

        {/* Links */}
        <div className="flex flex-wrap justify-center gap-x-8 gap-y-4">
          <Link 
            href="/docs" 
            className="text-sm font-medium text-zinc-400 hover:text-white transition-colors"
          >
            Documentation
          </Link>
          <a 
            href="https://scan.testnet.initia.xyz" 
            target="_blank" 
            rel="noopener noreferrer"
            className="text-sm font-medium text-zinc-400 hover:text-white transition-colors flex items-center gap-1"
          >
            Explorer
            <svg className="w-3 h-3 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
            </svg>
          </a>
          <a 
            href="https://github.com" 
            target="_blank" 
            rel="noopener noreferrer"
            className="text-sm font-medium text-zinc-400 hover:text-white transition-colors flex items-center gap-1"
          >
            GitHub
            <svg className="w-3 h-3 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
            </svg>
          </a>
        </div>

        {/* Disclaimer */}
        <div className="w-full flex flex-col items-center gap-4 pt-8 border-t border-white/5">
          <p className="text-sm font-medium text-zinc-500 text-center">
            Not Financial Advice
          </p>
        </div>

      </div>
    </footer>
  );
}