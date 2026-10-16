// install: bring the skills of the node in the working directory to the
// sources its configuration declares, with the skills CLI. The protocol
// is docs/install.txt. bin/clankos-run starts this in the clankos-skills
// image, with what the ClankOS image read of the configuration on
// standard input: {"sources": [...], "harnesses": [...] or null,
// "bin": a path or null, "image": a source or null}, each source as
// poslib's reader gives it. image is the ClankOS image's skills, from
// the repository and at the commit it was built from, which the
// ClankOS image gives at a repository's root.
//
// Nothing is changed until every source has been fetched into a scratch
// directory and every refusal checked. Then the skills of a declared
// source that are no longer declared, or declared at another ref, are
// removed, and the missing ones added, in the working directory. A
// skill from a source the configuration does not declare is
// wild-caught: someone installed it with the skills CLI, and it is left
// as it is.
//
// Exit: 0 done, 1 refused and nothing changed, 2 usage, 3 the skills CLI
// failed while changing the node.
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, lstatSync, mkdtempSync, readFileSync, readlinkSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const SLOTS = ['capture', 'start-up', 'wrap-up'];
const LOCK = 'skills-lock.json';
const node = process.cwd();

function fail(status, lines) {
  for (const line of lines) console.error(`install: ${line}`);
  process.exit(status);
}

// The text two sources are compared by, as poslib's source key.
function key(source) {
  return source.replace(/\/$/, '').replace(/\.git$/, '').replace(/^https:\/\/github\.com\//, '');
}

function lockEntries() {
  const file = join(node, LOCK);
  if (!existsSync(file)) return {};
  try {
    const skills = JSON.parse(readFileSync(file, 'utf8')).skills;
    return skills && typeof skills === 'object' && !Array.isArray(skills) ? skills : {};
  } catch {
    return {};
  }
}

function entryKey(entry) {
  return key(typeof entry.sourceUrl === 'string' ? entry.sourceUrl : String(entry.source));
}

// The skills CLI, with its JSON on standard output; its other output is
// kept for a failure.
function skills(args, cwd) {
  const run = spawnSync('skills', args, { cwd, env, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  let results = [];
  try {
    results = JSON.parse(run.stdout || '[]');
  } catch {
    results = [];
  }
  return { status: run.status, results: Array.isArray(results) ? results : [], errors: run.stderr };
}

function tracked(path) {
  return spawnSync('git', ['ls-files', '--error-unmatch', '--', path], { cwd: node, stdio: 'ignore' })
    .status === 0;
}

// Whether the entry at path is a link ClankOS's refresh made: one into
// the auto/ of the node's configuration directory.
function imageLink(path) {
  try {
    if (!lstatSync(path).isSymbolicLink()) return false;
  } catch {
    return false;
  }
  const target = resolve(join(path, '..'), readlinkSync(path));
  return ['.clanka', '.clankos', '.pos'].some((dir) => target.startsWith(join(node, dir, 'auto') + '/'));
}

let plan;
try {
  plan = JSON.parse(readFileSync(0, 'utf8'));
} catch {
  fail(2, ['the configuration was not given on standard input']);
}
const declared = plan.sources || [];
const sources = plan.image ? [...declared, { ...plan.image, kind: 'image' }] : declared;
const agents = plan.harnesses && plan.harnesses.length ? plan.harnesses : ['universal'];
const env = { ...process.env, GIT_TERMINAL_PROMPT: '0' };

// With GH_TOKEN, a github.com source given by its SSH URL is fetched over
// HTTPS with the token, so that neither the SSH client nor an agent is
// needed: Docker on a Mac cannot pass the host's agent socket into a
// container. The settings follow those clankos-run gives git.
if (env.GH_TOKEN) {
  const settings = [
    ['url.https://github.com/.insteadOf', 'git@github.com:'],
    ['url.https://github.com/.insteadOf', 'ssh://git@github.com/'],
    ['credential.https://github.com.helper',
      '!f() { test "$1" = get || exit 0; echo username=x-access-token; echo "password=$GH_TOKEN"; }; f'],
  ];
  let count = Number(env.GIT_CONFIG_COUNT) || 0;
  for (const [name, value] of settings) {
    env[`GIT_CONFIG_KEY_${count}`] = name;
    env[`GIT_CONFIG_VALUE_${count}`] = value;
    count += 1;
  }
  env.GIT_CONFIG_COUNT = String(count);
}

// 1. Each ref is a tag or a full commit id, and no branch.
const refused = [];
for (const source of sources) {
  const listed = spawnSync('git', ['ls-remote', '--heads', '--tags', '--', source.source],
    { encoding: 'utf8', env });
  if (listed.status !== 0) {
    refused.push(`${source.source}: cannot be read: ${listed.stderr.trim()}`);
    continue;
  }
  const refs = listed.stdout.split('\n').map((line) => line.split('\t')[1]).filter(Boolean);
  if (/^[0-9a-f]{40}$/.test(source.ref) || refs.includes(`refs/tags/${source.ref}`)) continue;
  if (refs.includes(`refs/heads/${source.ref}`)) {
    refused.push(`${source.source}: ${source.ref} is a branch; give a tag or a commit`);
  } else {
    refused.push(`${source.source}: ${source.ref} is no tag; a commit is given by its forty-digit id`);
  }
}
if (refused.length) fail(1, [...refused, 'nothing was changed']);

// 2. Each source fetched into a scratch directory, for its skills' names.
const stage = mkdtempSync(join(tmpdir(), 'clankos-install-'));
const supplied = [];
try {
  sources.forEach((source, index) => {
    const dir = join(stage, String(index));
    execFileSync('mkdir', ['-p', dir]);
    const run = skills(['add', `${source.source}#${source.ref}`, '--yes', '--json',
      '--agent', 'universal', '--skill', ...(source.skills || ['*'])], dir);
    const bad = run.results.filter((result) => result.status !== 'installed');
    if (run.status !== 0 || bad.length || !run.results.length) {
      const why = bad.map((result) => result.reason || result.error || result.status).join('; ');
      refused.push(`${source.source} at ${source.ref}: ${(why || run.errors).trim()}`);
      return;
    }
    for (const result of run.results) {
      if (result.ref !== source.ref) {
        refused.push(`${source.source}: the skills CLI cannot fetch it at a ref; give a URL ending .git`);
        return;
      }
    }
    let names = run.results.map((result) => result.name).sort();
    if (source.kind === 'image') {
      // A skill a declared source supplies takes the place of the image's.
      const others = new Set(supplied.flatMap((each) => each.names));
      names = names.filter((name) => !others.has(name));
    }
    if (names.length) supplied.push({ source, names });
  });
} finally {
  rmSync(stage, { recursive: true, force: true });
}
if (refused.length) fail(1, [...refused, 'nothing was changed']);

// 3. The refusals of a name.
const locked = lockEntries();
const declaredKeys = new Set(sources.map((source) => key(source.source)));
const wild = (name) => name in locked && !declaredKeys.has(entryKey(locked[name]));
const by = new Map();
for (const { source, names } of supplied) {
  for (const name of names) {
    const path = join(node, '.agents/skills', name);
    let present = false;
    try {
      lstatSync(path);
      present = true;
    } catch {
      present = false;
    }
    if (wild(name)) {
      refused.push(`${name}: installed from ${locked[name].source}, which the configuration`
        + ` does not declare, and supplied by ${source.source}; remove one`);
      continue;
    }
    const ours = name in locked || imageLink(path);
    if (source.kind === 'image') continue;
    if (source.kind === 'methodology' && !name.startsWith(`${source.name}-`)) {
      refused.push(`${name}: a skill of ${source.source} not named ${source.name}-NAME`);
    }
    if (name.startsWith('clankos-')) {
      refused.push(`${name}: the name clankos is reserved, and ${source.source} supplies it`);
    }
    if (by.has(name)) {
      refused.push(`${name}: supplied by ${by.get(name)} and by ${source.source}`);
    }
    by.set(name, source.source);
    if (SLOTS.includes(name)
        && ((present && !ours) || (plan.bin && tracked(join(plan.bin, name))))) {
      refused.push(`${name}: the repository fills this slot itself`);
    } else if (present && !ours) {
      refused.push(`${name}: the repository has a skill of its own of this name`);
    }
  }
}
if (refused.length) fail(1, [...refused, 'nothing was changed']);

// 4. Of the declared sources' skills, remove what is no longer declared,
// or is declared at another ref; add what is missing. A wild-caught
// skill is left.
const wanted = new Map();
for (const { source, names } of supplied) {
  for (const name of names) wanted.set(name, source);
}
const said = [];
for (const [name, entry] of Object.entries(locked).sort()) {
  if (wild(name)) continue;
  const source = wanted.get(name);
  if (source && entryKey(entry) === key(source.source) && entry.ref === source.ref) continue;
  const run = skills(['remove', name, '--yes'], node);
  if (run.status !== 0) fail(3, [...said, `removing ${name}: ${run.errors.trim()}`]);
  said.push(`removed ${name}`);
  delete locked[name];
}
for (const { source, names } of supplied) {
  const missing = names.filter((name) => !(name in locked));
  if (!missing.length) continue;
  for (const name of missing) {
    const path = join(node, '.agents/skills', name);
    if (imageLink(path)) rmSync(path);
  }
  const run = skills(['add', `${source.source}#${source.ref}`, '--yes', '--json',
    '--agent', ...agents, '--skill', ...missing], node);
  if (run.status !== 0 || run.results.some((result) => result.status !== 'installed')) {
    fail(3, [...said, `adding from ${source.source} at ${source.ref}: ${run.errors.trim()}`]);
  }
  for (const name of missing) said.push(`installed ${name} from ${source.source} at ${source.ref}`);
}
for (const line of said) console.log(line);
