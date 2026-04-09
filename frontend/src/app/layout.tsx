import type { Metadata } from 'next';
import { Plus_Jakarta_Sans, Outfit } from 'next/font/google';
import './globals.css';
import { Providers } from './providers';
import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';

const bodyFont = Plus_Jakarta_Sans({ 
  subsets: ['latin'], 
  variable: '--font-body' 
});

const displayFont = Outfit({ 
  subsets: ['latin'], 
  variable: '--font-display' 
});

export const metadata: Metadata = {
  title: 'Drip | Social Yield on Initia',
  description: 'Yield automated. Battles elevated.'
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
      <html lang="en" className={`${bodyFont.variable} ${displayFont.variable} dark`}>
        <body className="relative min-h-screen bg-[#050505] selection:bg-blue-500/30 font-sans">
        
        {/* AMBIENT GLOW — subtle purple atmosphere behind all pages */}
        <div className="fixed inset-0 z-[-1] pointer-events-none bg-[#050505] overflow-hidden">
          <div className="absolute -top-32 left-1/2 -translate-x-1/2 w-[900px] h-[700px] bg-purple-600/20 rounded-full blur-[180px]" />
          <div className="absolute bottom-[-10%] right-[-5%] w-[600px] h-[500px] bg-fuchsia-700/12 rounded-full blur-[150px]" />
          <div className="absolute top-1/2 left-[-10%] w-[400px] h-[400px] bg-violet-800/10 rounded-full blur-[140px]" />
        </div>

        <Providers>
          <Navbar />
          {/* Main content wrapper */}
          <main className="relative z-10 flex-grow min-h-screen">
            {children}
          </main>
          <Footer />
        </Providers>

      </body>
    </html>
  );
}