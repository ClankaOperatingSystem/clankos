// install: bring the skills of the node in the working directory to the
// sources its configuration declares, with the skills CLI. The protocol
// is docs/install.txt. bin/clankos-run starts this in the clankos-skills
// image, with what the ClankOS image read of the configuration on
// standard input: {"sources": [...], "harnesses": [...] or null,
// "bin": a path or null, "clankos": a git URL or null, "uninstall": [...]},
// each source as poslib's reader gives it. uninstall names skills to
// remove that are left otherwise: those of a source the methodology
// command has just removed. clankos is the repository the ClankOS image
// was built from: a source of that repository is method zero, declared
// as any other source is, and alone may supply skills named clankos-NAME.
//
// Nothing is changed until every source has been fetched into a scratch
// directory and every refusal checked. Then the skills of a declared
// source that are no longer declared, declared at another ref, or linked
// for other harnesses than those declared, are removed, and the missing
// ones added, in the working directory. Each skill is a folder in
// .agents/skills/, and each declared harness that reads a directory of
// its own has a link there to it. A
// skill from a source the configuration does not declare is
// wild-caught: someone installed it with the skills CLI, and it is left
// as it is, unless uninstall names it.
//
// Exit: 0 done, 1 refused and nothing changed, 2 usage, 3 the skills CLI
// failed while changing the node.
import { locks, hash, paths } from './installation.mjs';
import {
  changing, key, nameRefusals, owners, preparation, refRefusal, untouched, wanted as wantedBy,
} from './rules.mjs';
import { execFileSync, spawnSync } from 'node:child_process';
import {
  existsSync, lstatSync, mkdtempSync, readdirSync, readFileSync, readlinkSync, rmSync, symlinkSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const LOCK = 'skills-lock.json';
const node = process.cwd();

function fail(status, lines) {
  for (const line of lines) console.error(`install: ${line}`);
  process.exit(status);
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

// Remove the line with which an earlier refresh had Git ignore its link
// at path, a path in the node, from the repository's info/exclude.
// Otherwise Git would ignore the skill installed there. Refresh may
// have removed the link already, and leaves the line.
function unexclude(path) {
  const git = (args) => spawnSync('git', args, { cwd: node, encoding: 'utf8' }).stdout.trim();
  const file = git(['rev-parse', '--git-path', 'info/exclude']);
  if (!file || !existsSync(resolve(node, file))) return;
  const line = `/${git(['rev-parse', '--show-prefix'])}${path}`;
  const lines = readFileSync(resolve(node, file), 'utf8').split('\n');
  const kept = lines.filter((each) => each !== line);
  if (kept.length < lines.length) writeFileSync(resolve(node, file), kept.join('\n'));
}

let plan;
try {
  plan = JSON.parse(readFileSync(0, 'utf8'));
} catch {
  fail(2, ['the configuration was not given on standard input']);
}
const explicit = plan.mode === 'apply-v1';
const sources = plan.sources || [];
const clankos = plan.clankos ? key(plan.clankos) : null;
let initial;
try { if (explicit) initial = locks(node); }
catch (error) { fail(1, [error.message]); }
const managed = plan.managed || [];
const agents = [...new Set(['universal', ...(plan.harnesses || [])])];
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
  const refusal = refRefusal(source, refs);
  if (refusal) refused.push(refusal);
}
if (refused.length) fail(1, [...refused, 'nothing was changed']);

// The harnesses each installed skill is linked for, as the skills CLI
// lists them.
function links(dir) {
  const run = skills(['list', '--json'], dir);
  if (explicit && run.status !== 0) fail(1, [`cannot list installed skills: ${run.errors}`]);
  return new Map(run.results.map((each) => [each.name, [...(each.agents || [])].sort().join(', ')]));
}

// A harness's directory in the node that is a link to .agents/skills/,
// such as .claude/skills: the skills CLI lists each skill as linked for
// that harness. Each scratch directory has the same links, so that a
// skill's harnesses there are the ones it has in the node.
const shared = readdirSync(node).filter((entry) => {
  const path = join(node, entry, 'skills');
  try {
    return entry.startsWith('.') && entry !== '.agents' && lstatSync(path).isSymbolicLink()
      && resolve(join(node, entry), readlinkSync(path)) === join(node, '.agents/skills');
  } catch {
    return false;
  }
});

// 2. Each source fetched into a scratch directory, for its skills' names
// and the harnesses they are linked for.
const stage = mkdtempSync(join(tmpdir(), 'clankos-install-'));
const supplied = [];
try {
  sources.forEach((source, index) => {
    const dir = join(stage, String(index));
    execFileSync('mkdir', ['-p', dir]);
    if (shared.length) execFileSync('mkdir', ['-p', join(dir, '.agents/skills')]);
    for (const entry of shared) {
      execFileSync('mkdir', ['-p', join(dir, entry)]);
      symlinkSync('../.agents/skills', join(dir, entry, 'skills'));
    }
    const run = skills(['add', `${source.source}#${source.ref}`, '--yes', '--json',
      '--agent', ...agents, '--skill', ...(source.skills || ['*'])], dir);
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
    const names = run.results.map((result) => result.name).sort();
    if (names.length) supplied.push({ source, names, links: links(dir), staged: explicit ? locks(dir) : {} });
  });
} finally {
  rmSync(stage, { recursive: true, force: true });
}
if (refused.length) fail(1, [...refused, 'nothing was changed']);

// 3. The refusals of a name.
const locked = explicit ? initial : lockEntries();
const { declared: declaredKeys, owned, keep, wild } = owners({
  explicit, sources, locked, managed, uninstall: plan.uninstall || [], seed: plan.seed,
});
refused.push(...nameRefusals(supplied, {
  explicit, clankos, locked, managed, wild,
  inspect: (name) => {
    const path = join(node, '.agents/skills', name);
    let present = false;
    try {
      lstatSync(path);
      present = true;
    } catch {
      present = false;
    }
    return {
      present,
      linked: imageLink(path),
      filled: () => Boolean(plan.bin && tracked(join(plan.bin, name))),
      hash: () => hash(path),
    };
  },
}));
if (refused.length) fail(1, [...refused, 'nothing was changed']);

// 4. Of the declared sources' skills, remove what is no longer declared,
// is declared at another ref, or is linked for other harnesses; add what
// is missing. A wild-caught skill is left, and one uninstall names is
// removed.
const want = wantedBy(supplied, explicit);
const wanted = want.sources;
const installedLinks = links(node);
const isChanging = (name, entry) => changing(name, entry, {
  explicit, want, keep, wild, installedLinks,
  complete: (name) => existsSync(join(node, '.agents/skills', name, 'SKILL.md')),
});
let prepared;
if (explicit) {
  try {
    paths(node, [...new Set([...Object.entries(locked).filter(([name, entry]) => wanted.has(name)
      || isChanging(name, entry)).map(([name]) => name), ...wanted.keys(),
    ...managed.filter((each) => each.disposition !== 'keep' && !(each.skill in locked)).map((each) => each.skill)])]);
    const actual = untouched({
      locked, wanted, isChanging, managed,
      inspect: (name) => ({
        present: existsSync(join(node, '.agents/skills', name)),
        hash: () => hash(join(node, '.agents/skills', name)),
      }),
    });
    prepared = preparation({
      locked, want, isChanging, owned, seed: plan.seed, declared: declaredKeys, actual,
    });
    if (plan.prepare) { console.log(JSON.stringify(prepared)); process.exit(0); }
    if (JSON.stringify(prepared) !== JSON.stringify(plan.expected)) {
      throw Error('installation changed after preflight; repeat apply-v1');
    }
  } catch (error) { fail(1, [error.message]); }
}
const said = [];
for (const [name, entry] of Object.entries(locked).sort()) {
  if (!isChanging(name, entry)) continue;
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
    unexclude(`.agents/skills/${name}`);
  }
  const run = skills(['add', `${source.source}#${source.ref}`, '--yes', '--json',
    '--agent', ...agents, '--skill', ...missing], node);
  if (run.status !== 0 || run.results.some((result) => result.status !== 'installed')) {
    fail(3, [...said, `adding from ${source.source} at ${source.ref}: ${run.errors.trim()}`]);
  }
  for (const name of missing) said.push(`installed ${name} from ${source.source} at ${source.ref}`);
}
for (const line of said) console.log(line);
