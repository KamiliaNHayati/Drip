// Chain configuration for Drip rollup (drip-1)
// Use NEXT_PUBLIC_DRIP_RPC_URL on Vercel when tunneling / hosting JSON-RPC publicly.
export const DRIP_RPC_URL =
  (typeof process !== 'undefined' && process.env.NEXT_PUBLIC_DRIP_RPC_URL) ||
  'http://localhost:8545';

export const DRIP_CHAIN_ID = 2202255493061218 as const;

export const drip1 = {
  id: DRIP_CHAIN_ID,
  name: 'Drip',
  nativeCurrency: { name: 'Drip', symbol: 'udrip', decimals: 18 },
  rpcUrls: {
    default: { http: [DRIP_RPC_URL] },
  },
} as const;