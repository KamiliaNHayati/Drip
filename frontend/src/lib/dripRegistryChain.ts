import type { Chain } from '@initia/initia-registry-types';

/**
 * InterwovenKit resolves `defaultChainId` against Initia's chain registry.
 * Custom rollups (drip-1) are not bundled in TESTNET — pass this as `customChain`.
 *
 * URLs default to local dev; set NEXT_PUBLIC_* on Vercel when exposing your node.
 */
export function buildDripRegistryChain(): Chain {
  const jsonRpc =
    (typeof process !== 'undefined' && process.env.NEXT_PUBLIC_DRIP_RPC_URL) ||
    'http://localhost:8545';
  const rest =
    (typeof process !== 'undefined' && process.env.NEXT_PUBLIC_DRIP_REST_URL) ||
    'http://localhost:1317';
  const tmRpc =
    (typeof process !== 'undefined' && process.env.NEXT_PUBLIC_DRIP_TM_RPC) ||
    'http://localhost:26657';

  return {
    chain_name: 'drip',
    chain_id: 'drip-1',
    evm_chain_id: 2202255493061218,
    pretty_name: 'Drip',
    network_type: 'testnet',
    bech32_prefix: 'init',
    fees: {
      fee_tokens: [
        {
          denom: 'udrip',
          fixed_min_gas_price: 0.001,
        },
      ],
    },
    apis: {
      rpc: [{ address: tmRpc, provider: 'drip' }],
      rest: [{ address: rest, provider: 'drip' }],
      'json-rpc': [{ address: jsonRpc, provider: 'drip' }],
    },
    metadata: {
      minitia: {
        type: 'minievm',
        version: '1.2.15',
      },
    },
  };
}

export const dripRegistryChain = buildDripRegistryChain();
