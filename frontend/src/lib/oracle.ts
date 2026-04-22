export function getDefensiveStatusMessage(statusCode: string, consecutiveDrops?: number) {
  switch (statusCode) {
    case 'DEFENSIVE_MODE':
      return `Compounding paused — price dropped ${consecutiveDrops ?? 'N'} cycles in a row.`;
    case 'STALE_ORACLE':
      return 'Oracle price temporarily unavailable. Compounding paused.';
    case 'ACTIVE':
    default:
      return 'Auto-compounding active';
  }
}

export function isDefensive(statusCode: string): boolean {
  return statusCode === 'DEFENSIVE_MODE' || statusCode === 'STALE_ORACLE';
}
