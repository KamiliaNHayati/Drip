'use client';

import { PropsWithChildren, useEffect } from 'react';
import { createConfig, http, WagmiProvider } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { 
  InterwovenKitProvider, 
  injectStyles, 
  initiaPrivyWalletConnector,
  TESTNET 
} from '@initia/interwovenkit-react';
import interwovenKitStyles from '@initia/interwovenkit-react/styles.js';
import { drip1, DRIP_RPC_URL } from '@/lib/chain';

const wagmiConfig = createConfig({
  connectors: [initiaPrivyWalletConnector],
  chains: [drip1],
  transports: {
    [drip1.id]: http(DRIP_RPC_URL),
  },
  ssr: true,
});

const queryClient = new QueryClient();

export function Providers({ children }: PropsWithChildren) {
  useEffect(() => {
    injectStyles(interwovenKitStyles);
    // Suppress Amplitude noise in console
    const originalError = console.error;
    console.error = (...args: unknown[]) => {
      if (typeof args[0] === 'string' && args[0].includes('Amplitude')) return;
      originalError.apply(console, args);
    };
  }, []);

  return (
    <QueryClientProvider client={queryClient}>
      <WagmiProvider config={wagmiConfig}>
        <InterwovenKitProvider {...TESTNET} defaultChainId="drip-1" disableAnalytics>
          {children}
        </InterwovenKitProvider>
      </WagmiProvider>
    </QueryClientProvider>
  );
}