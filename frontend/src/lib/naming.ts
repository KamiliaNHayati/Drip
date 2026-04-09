export function truncateAddress(address: string): string {
  if (!address || address.length < 10) return address;
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

// Mock REST API call to Initia Name Service
export async function resolveInitName(address: string): Promise<string> {
  // In production, this would fetch from an Initia indexing API or contract
  // const res = await fetch(`https://api.initia.xyz/v1/names/${address}`);
  // const data = await res.json();
  // return data.name || truncateAddress(address);
  
  // Mock logic
  if (address.toLowerCase() === '0x1234567890abcdef1234567890abcdef12345678') {
    return 'spartan.init';
  }
  if (address.toLowerCase() === '0x9876543210abcdef1234567890abcdef12345678') {
    return 'whale.init';
  }
  
  return truncateAddress(address);
}

// Batch resolution for leaderboards
export async function resolveInitNames(addresses: string[]): Promise<string[]> {
  return Promise.all(addresses.map(resolveInitName));
}
