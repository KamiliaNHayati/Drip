// Chain configuration for Drip rollup (drip-1)
export const DRIP_RPC_URL = 'http://localhost:8545' as const;
export const DRIP_CHAIN_ID = 9786571 as const;

export const drip1 = {
  id: DRIP_CHAIN_ID,
  name: 'Drip',
  nativeCurrency: { name: 'INIT', symbol: 'INIT', decimals: 18 },
  rpcUrls: {
    default: { http: [DRIP_RPC_URL] },
  },
} as const;