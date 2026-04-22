import fs from 'fs';
import path from 'path';

const outDir = path.resolve('../contracts/out');
const dest = path.resolve('./src/lib/contracts.ts');

const targets = [
  { name: 'DripPool', file: 'DripPool.sol/DripPool.json', address: '0x2E97f225dcC77780bB62059668144F64dfF5eF04' },
  { name: 'DripToken', file: 'DripToken.sol/DripToken.json', address: '' },
  { name: 'VaultFactory', file: 'VaultFactory.sol/VaultFactory.json', address: '0x9D8d7DbEccD15438111E0D162caf2BAF1C9B1D61' },
  { name: 'DripVault', file: 'DripVault.sol/DripVault.json', address: '' },
  { name: 'CompetitionManager', file: 'CompetitionManager.sol/CompetitionManager.json', address: '0x519Bd4777f72d41dE47FD1490E099f12b46A2Cb5' },
  { name: 'BattleManager', file: 'BattleManager.sol/BattleManager.json', address: '0xa44C796f39955daDbA335f990E44cACa412D596C' },
  { name: 'GhostRegistry', file: 'GhostRegistry.sol/GhostRegistry.json', address: '0xdfCC740D3dD3a48802692B903a93f76A3774b1CA' },
  { name: 'SquadManager', file: 'SquadManager.sol/SquadManager.json', address: '0x1680E051941DbD2BFBD7d310CBe1042e1FD8De25' },
];

let output = `// Auto-generated from forge artifacts\n\n`;

for (const t of targets) {
  const jsonPath = path.join(outDir, t.file);
  const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  
  if (t.address) {
    output += `export const ${t.name}Address = '${t.address}' as const;\n`;
  }
  output += `export const ${t.name}ABI = ${JSON.stringify(data.abi)} as const;\n\n`;
}

output += `export const INIT_TOKEN = '0x2eE7007DF876084d4C74685e90bB7f4cd7c86e22' as const;\n`;
output += `export const INIT_DECIMALS = 18;\n`;

// Make sure directory exists
fs.mkdirSync(path.dirname(dest), { recursive: true });
fs.writeFileSync(dest, output);
console.log('Successfully generated contracts.ts');
