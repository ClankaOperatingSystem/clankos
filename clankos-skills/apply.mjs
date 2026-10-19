// Apply one repository after every node passes preflight. Keep state on failure.
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { readFileSync } from 'node:fs';
import { atomic, boundary, entryKey, hash, identity, installer, key, locks, read, stat } from './installation.mjs';

const root = process.cwd();
let started = false;
function run(request, node) {
  const result = spawnSync(process.execPath, [installer], {
    cwd: node, input: JSON.stringify(request), encoding: 'utf8', maxBuffer: 16 * 1024 * 1024,
  });
  if (result.status !== 0) throw Error(`${node}: ${result.stderr || result.error || 'installer failed'}`);
  return result.stdout;
}
try {
  const plan = JSON.parse(readFileSync(0, 'utf8'));
  if (plan.schema !== 1 || !Array.isArray(plan.nodes) || typeof plan.state !== 'string') {
    throw Error('incompatible apply input; use matching ClankOS runtime and skills images');
  }
  const state = boundary(root, plan.state);
  const current = () => {
    if (read(state) !== plan.before) throw Error('installation state changed; repeat apply-v1');
    for (const node of plan.nodes) {
      boundary(root, node.path);
      if (node.config && read(boundary(root, node.config)) !== node.text) {
        throw Error(`configuration changed: ${node.config}; repeat apply-v1`);
      }
    }
  };
  current();
  const managed = new Map();
  const wanted = new Map();
  const work = [];
  for (const node of plan.nodes) {
    for (const entry of node.managed) managed.set(identity(entry), entry);
    const dir = boundary(root, node.path);
    if (!stat(dir)) continue;
    const request = { ...node, mode: 'apply-v1', prepare: true, seed: plan.before === null };
    const prepared = JSON.parse(run(request, dir));
    for (const entry of [...prepared.owned, ...prepared.wanted]) {
      const own = { node: node.path, source: key(entry.source), skill: entry.skill, disposition: null };
      if (!managed.has(identity(own))) managed.set(identity(own), own);
    }
    for (const entry of prepared.wanted) {
      const own = { node: node.path, source: key(entry.source), skill: entry.skill, disposition: null };
      wanted.set(identity(own), own);
    }
    work.push({ node, dir, request, prepared });
  }
  current();
  const serialize = (entries) => JSON.stringify({ schema: 1,
    managed: [...entries].sort((a, b) => identity(a).localeCompare(identity(b))),
  }) + '\n';
  const pending = serialize(managed.values());
  atomic(state, pending);
  started = true;
  plan.before = pending;
  for (const item of work) {
    current();
    process.stdout.write(run({ ...item.request, prepare: false, expected: item.prepared }, item.dir));
    const installed = locks(item.dir);
    for (const entry of item.prepared.wanted) {
      const actual = installed[entry.skill];
      if (!actual || entryKey(actual) !== entry.source || actual.ref !== entry.ref || actual.computedHash !== entry.hash
          || !stat(join(item.dir, '.agents/skills', entry.skill, 'SKILL.md'))
          || hash(join(item.dir, '.agents/skills', entry.skill)) !== actual.computedHash) {
        throw Error(`${item.node.path}/${entry.skill}: installation incomplete; repeat apply-v1`);
      }
    }
    for (const name of item.prepared.remove) {
      if (!item.prepared.wanted.some((entry) => entry.skill === name)
          && (installed[name] || stat(join(item.dir, '.agents/skills', name)))) {
        throw Error(`${item.node.path}/${name}: removal incomplete; repeat apply-v1`);
      }
    }
  }
  current();
  atomic(state, serialize(wanted.values()));
} catch (error) {
  console.error(`apply-v1: ${error.message.trim()}`);
  if (started) console.error('apply-v1: configuration and pending ownership retained; correct the error and repeat apply-v1');
  process.exit(started ? 3 : 1);
}
