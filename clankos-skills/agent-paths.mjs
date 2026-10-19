// Read installation directories from the pinned skills CLI's bundled agent table.
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
const dist = '/usr/local/lib/node_modules/skills/dist';
const paths = new Set();
for (const file of readdirSync(dist).filter((name) => name.endsWith('.mjs'))) {
  for (const match of readFileSync(`${dist}/${file}`, 'utf8').matchAll(/skillsDir:\s*"([^"\n]+)"/g)) {
    if (!/^(?:[.a-zA-Z0-9_-]+\/)*skills$/.test(match[1]) || match[1].split('/').includes('..')) {
      throw Error(`unexpected skills directory: ${match[1]}`);
    }
    paths.add(match[1]);
  }
}
if (!paths.has('.agents/skills') || !paths.has('.claude/skills')) throw Error('skills agent table not found');
writeFileSync(new URL('./agent-paths.json', import.meta.url), JSON.stringify([...paths].sort()) + '\n');
