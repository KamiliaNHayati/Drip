export function truncateAddress(address: string | undefined): string {
  if (!address) return '';
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export function formatINIT(amount: bigint | string | number | undefined): string {
  if (amount === undefined || amount === null) return '0';
  const val = typeof amount === 'bigint' ? amount : BigInt(amount);
  const num = Number(val) / 1e18;
  return new Intl.NumberFormat('en-US', {
    maximumFractionDigits: 4,
  }).format(num);
}
