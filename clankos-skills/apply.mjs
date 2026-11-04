// Apply one repository after every node passes preflight. Keep state on failure.
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { readFileSync } from 'node:fs';
import { atomic, boundary, hash, installer, locks, read, stat } from './installation.mjs';
import { ownership, serialize, unfinished } from './rules.mjs';

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
  const work = [];
  for (const node of plan.nodes) {
    const dir = boundary(root, node.path);
    if (!stat(dir)) continue;
    const request = { ...node, mode: 'apply-v1', prepare: true, seed: plan.before === null };
    work.push({ node, path: node.path, dir, request, prepared: JSON.parse(run(request, dir)) });
  }
  const { pending: managed, done } = ownership(plan.nodes, work);
  current();
  const pending = serialize(managed);
  atomic(state, pending);
  started = true;
  plan.before = pending;
  for (const item of work) {
    current();
    process.stdout.write(run({ ...item.request, prepare: false, expected: item.prepared }, item.dir));
    const installed = locks(item.dir);
    const why = unfinished(item.node.path, item.prepared, installed, (name) => {
      const folder = join(item.dir, '.agents/skills', name);
      return {
        present: Boolean(stat(folder)),
        complete: Boolean(stat(join(folder, 'SKILL.md'))),
        hash: () => hash(folder),
      };
    });
    if (why) throw Error(why);
  }
  current();
  atomic(state, serialize(done));
} catch (error) {
  console.error(`apply-v1: ${error.message.trim()}`);
  if (started) console.error('apply-v1: configuration and pending ownership retained; correct the error and repeat apply-v1');
  process.exit(started ? 3 : 1);
}
