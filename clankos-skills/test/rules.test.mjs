// Run: make check. The rules of rules.mjs, on the host. Each test gives
// a rule what install or apply-v1 would read from a node: its declared
// sources, its lock, the identities ClankOS manages and what the skills
// CLI staged.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  changing, identity, key, nameRefusals, owners, ownership, preparation, refRefusal,
  serialize, unfinished, untouched, wanted,
} from '../rules.mjs';

const CLANKOS = 'https://github.com/ClankaOperatingSystem/clankos.git';
const TOOLS = 'https://github.com/acme/tools.git';
const source = (url, extra = {}) => ({ source: url, ref: 'v1', ...extra });
const entry = (from, extra = {}) => ({ source: key(from), ref: 'v1', computedHash: 'h1', ...extra });
const nothing = () => ({ present: false, linked: false, filled: () => false, hash: () => null });

// The refusals of what supplied names, for a node holding locked and
// managed, held as inspect says.
function refusals(supplied, { explicit = false, locked = {}, managed = [], inspect = nothing,
  sources = supplied.map((each) => each.source) } = {}) {
  const { wild } = owners({ explicit, sources, locked, managed });
  return nameRefusals(supplied, { explicit, clankos: key(CLANKOS), locked, managed, wild, inspect });
}

test('a source is fetched at a tag or a commit, and never a branch', () => {
  const refs = ['refs/tags/v1', 'refs/heads/main'];
  assert.equal(refRefusal(source(TOOLS), refs), null);
  assert.equal(refRefusal(source(TOOLS, { ref: 'a'.repeat(40) }), refs), null);
  assert.match(refRefusal(source(TOOLS, { ref: 'main' }), refs), /main is a branch/);
  assert.match(refRefusal(source(TOOLS, { ref: 'v2' }), refs), /v2 is no tag/);
});

test('a source key is the same for each spelling of a GitHub repository', () => {
  assert.equal(key('https://github.com/acme/tools.git'), 'acme/tools');
  assert.equal(key('https://github.com/acme/tools/'), 'acme/tools');
  assert.equal(key('acme/tools'), 'acme/tools');
});

test('install owns the skills of declared sources and those uninstall names', () => {
  const locked = { 'tools-lint': entry(TOOLS), stray: entry('acme/stray'), gone: entry('acme/gone') };
  const { wild } = owners({ explicit: false, sources: [source(TOOLS)], locked, uninstall: ['gone'] });
  assert.equal(wild('tools-lint'), false);
  assert.equal(wild('stray'), true);
  assert.equal(wild('gone'), false);
  assert.equal(wild('not-installed'), false);
});

test('apply-v1 owns the managed skills, and on its first run those of declared sources', () => {
  const locked = { 'tools-lint': entry(TOOLS), other: entry(TOOLS) };
  const managed = [{ node: '.', source: 'acme/tools', skill: 'tools-lint', disposition: null }];
  const later = owners({ explicit: true, sources: [source(TOOLS)], locked, managed });
  assert.equal(later.wild('tools-lint'), false);
  assert.equal(later.wild('other'), true);
  const first = owners({ explicit: true, sources: [source(TOOLS)], locked, managed, seed: true });
  assert.equal(first.wild('other'), false);
});

test('a skill is kept only in apply-v1, and only when its disposition is keep', () => {
  const locked = { 'tools-lint': entry(TOOLS) };
  const managed = [{ node: '.', source: 'acme/tools', skill: 'tools-lint', disposition: 'keep' }];
  const args = { sources: [], locked, managed };
  assert.equal(owners({ ...args, explicit: true }).keep('tools-lint', locked['tools-lint']), true);
  assert.equal(owners({ ...args, explicit: false }).keep('tools-lint', locked['tools-lint']), false);
});

test('names from declared sources with nothing in their way are not refused', () => {
  assert.deepEqual(refusals([{ source: source(TOOLS), names: ['tools-lint'] }]), []);
});

test('a name a wild-caught skill holds is refused', () => {
  const [why] = refusals([{ source: source(TOOLS), names: ['stray'] }],
    { locked: { stray: entry('acme/stray') } });
  assert.match(why, /^stray: installed from acme\/stray, which the configuration does not declare/);
});

test('only ClankOS supplies skills named clankos-NAME', () => {
  assert.deepEqual(refusals([{ source: source(CLANKOS), names: ['clankos-lint'] }]), []);
  assert.match(refusals([{ source: source(TOOLS), names: ['clankos-lint'] }])[0],
    /the name clankos is reserved/);
});

test('a methodology supplies only skills named after it', () => {
  const methodology = source(TOOLS, { kind: 'methodology', name: 'tools' });
  assert.deepEqual(refusals([{ source: methodology, names: ['tools-lint'] }]), []);
  assert.match(refusals([{ source: methodology, names: ['lint'] }])[0], /not named tools-NAME/);
});

test('a name two sources supply is refused', () => {
  const [why] = refusals([
    { source: source(TOOLS), names: ['lint'] },
    { source: source('https://github.com/acme/more.git'), names: ['lint'] },
  ]);
  assert.match(why, /^lint: supplied by .*tools.git and by .*more.git/);
});

test('a slot the repository fills, by a skill or by a command in its bin, is refused', () => {
  const supplied = [{ source: source(CLANKOS), names: ['capture'] }];
  const own = () => ({ ...nothing(), present: true });
  const command = () => ({ ...nothing(), filled: () => true });
  assert.match(refusals(supplied, { inspect: own })[0], /fills this slot itself/);
  assert.match(refusals(supplied, { inspect: command })[0], /fills this slot itself/);
});

test('a skill of the repository\'s own is refused, and a link refresh made is not', () => {
  const supplied = [{ source: source(TOOLS), names: ['lint'] }];
  const own = () => ({ ...nothing(), present: true });
  const link = () => ({ ...nothing(), present: true, linked: true });
  assert.match(refusals(supplied, { inspect: own })[0], /has a skill of its own/);
  assert.deepEqual(refusals(supplied, { inspect: link }), []);
});

test('in apply-v1 a managed skill with no lock entry is ClankOS\'s when its hash is the staged one', () => {
  const managed = [{ node: '.', source: 'acme/tools', skill: 'lint', disposition: null }];
  const supplied = [{ source: source(TOOLS), names: ['lint'], staged: { lint: { computedHash: 'h1' } } }];
  const at = (hash) => () => ({ ...nothing(), present: true, hash });
  assert.deepEqual(refusals(supplied, { explicit: true, managed, inspect: at(() => 'h1') }), []);
  assert.match(refusals(supplied, { explicit: true, managed, inspect: at(() => 'h2') })[0],
    /has a skill of its own/);
  assert.deepEqual(refusals(supplied, { explicit: true, managed, inspect: at(() => {
    throw Error('symbolic skill content: lint/x');
  }) }), ['symbolic skill content: lint/x', 'lint: the repository has a skill of its own of this name']);
});

// Whether name, locked as installed, changes, where the sources supply
// supplied and the node links each skill for installedLinks.
function changes(name, installed, supplied, { explicit = false, managed = [],
  installedLinks = new Map([[name, 'universal']]), complete = () => true } = {}) {
  const locked = { [name]: installed };
  const want = wanted(supplied, explicit);
  const { keep, wild } = owners({ explicit, sources: supplied.map((each) => each.source), locked, managed });
  return changing(name, installed, { explicit, want, keep, wild, installedLinks, complete });
}
const supplies = (from, names, extra = {}) => ({
  source: from, names, links: new Map(names.map((name) => [name, 'universal'])),
  staged: Object.fromEntries(names.map((name) => [name, { computedHash: 'h1' }])), ...extra,
});

test('a skill installed as declared does not change', () => {
  assert.equal(changes('lint', entry(TOOLS), [supplies(source(TOOLS), ['lint'])]), false);
  assert.equal(changes('lint', entry(TOOLS), [supplies(source(TOOLS), ['lint'])], { explicit: true }), false);
});

test('a skill at another ref, from another source or linked for other harnesses changes', () => {
  const declared = [supplies(source(TOOLS), ['lint'])];
  assert.equal(changes('lint', entry(TOOLS, { ref: 'v0' }), declared), true);
  assert.equal(changes('lint', entry('acme/more'), declared), true);
  assert.equal(changes('lint', entry(TOOLS), declared,
    { installedLinks: new Map([['lint', 'claude-code, universal']]) }), true);
});

test('a skill no longer declared is removed, unless it is wild-caught or kept', () => {
  const managed = (disposition) => [{ node: '.', source: 'acme/tools', skill: 'lint', disposition }];
  assert.equal(changes('lint', entry(TOOLS), [supplies(source(TOOLS), [])]), true);
  assert.equal(changes('lint', entry(TOOLS), []), false);
  assert.equal(changes('lint', entry(TOOLS), [], { explicit: true, managed: managed(null) }), true);
  assert.equal(changes('lint', entry(TOOLS), [], { explicit: true, managed: managed('keep') }), false);
});

test('in apply-v1 a skill with no SKILL.md or another hash changes', () => {
  const declared = [supplies(source(TOOLS), ['lint'])];
  assert.equal(changes('lint', entry(TOOLS), declared, { explicit: true, complete: () => false }), true);
  assert.equal(changes('lint', entry(TOOLS, { computedHash: 'h0' }), declared, { explicit: true }), true);
  assert.equal(changes('lint', entry(TOOLS, { computedHash: 'h0' }), declared), false);
});

test('apply-v1 refuses a skill with local changes, and records the hashes it found', () => {
  const locked = { lint: entry(TOOLS), other: entry(TOOLS) };
  const args = (hashes, managed = []) => ({
    locked, wanted: new Map([['lint', source(TOOLS)]]), isChanging: () => false, managed,
    inspect: (name) => ({ present: name in hashes, hash: () => hashes[name] ?? null }),
  });
  assert.deepEqual(untouched(args({ lint: 'h1', other: 'h9' })), { lint: 'h1' });
  assert.deepEqual(untouched(args({})), { lint: null });
  assert.throws(() => untouched(args({ lint: 'h2' })), /^Error: lint: local changes/);
});

test('apply-v1 refuses to remove a managed skill that has files and no lock entry', () => {
  const managed = (disposition) => [{ node: '.', source: 'acme/tools', skill: 'gone', disposition }];
  const args = (present, disposition) => ({
    locked: {}, wanted: new Map(), isChanging: () => false, managed: managed(disposition),
    inspect: () => ({ present, hash: () => null }),
  });
  assert.throws(() => untouched(args(true, null)), /gone: managed files have no lock entry/);
  assert.deepEqual(untouched(args(false, null)), {});
  assert.deepEqual(untouched(args(true, 'keep')), {});
});

test('the preparation names what is wanted, removed and owned', () => {
  const locked = { lint: entry(TOOLS, { ref: 'v0' }), stray: entry('acme/stray'), old: entry(TOOLS) };
  const supplied = [supplies(source(TOOLS), ['lint', 'new'])];
  const managed = [{ node: '.', source: 'acme/tools', skill: 'lint', disposition: null }];
  const { declared, owned, keep, wild } = owners({ explicit: true, sources: [source(TOOLS)], locked, managed });
  const want = wanted(supplied, true);
  const isChanging = (name, installed) => changing(name, installed, {
    explicit: true, want, keep, wild, installedLinks: new Map(), complete: () => true,
  });
  const args = { locked, want, isChanging, owned, declared, actual: {} };
  const later = preparation({ ...args, seed: false });
  assert.deepEqual(later.wanted, [
    { skill: 'lint', source: 'acme/tools', ref: 'v1', hash: 'h1' },
    { skill: 'new', source: 'acme/tools', ref: 'v1', hash: 'h1' },
  ]);
  assert.deepEqual(later.remove, ['lint']);
  assert.deepEqual(later.owned, [{ skill: 'lint', source: 'acme/tools' }]);
  assert.deepEqual(preparation({ ...args, seed: true }).owned,
    [{ skill: 'lint', source: 'acme/tools' }, { skill: 'old', source: 'acme/tools' }]);
});

test('apply-v1 saves every identity before it changes a node, and the wanted ones after', () => {
  const kept = { node: 'home', source: 'acme/tools', skill: 'tools-lint', disposition: 'keep' };
  const nodes = [{ path: '.', managed: [] }, { path: 'home', managed: [kept] }];
  const work = [
    { path: '.', prepared: { owned: [{ skill: 'old', source: 'acme/tools' }],
      wanted: [{ skill: 'new', source: 'acme/tools' }] } },
    { path: 'home', prepared: { owned: [{ skill: 'tools-lint', source: 'acme/tools' }], wanted: [] } },
  ];
  const { pending, done } = ownership(nodes, work);
  const of = (entries) => entries.map((each) => [each.node, each.skill, each.disposition]).sort();
  assert.deepEqual(of(pending), [['.', 'new', null], ['.', 'old', null], ['home', 'tools-lint', 'keep']]);
  assert.deepEqual(of(done), [['.', 'new', null]]);
});

test('the saved state is in identity order', () => {
  const a = { node: '.', source: 'acme/tools', skill: 'a', disposition: null };
  const b = { node: '.', source: 'acme/tools', skill: 'b', disposition: null };
  assert.equal(serialize([b, a]), serialize([a, b]));
  assert.deepEqual(JSON.parse(serialize([b, a])).managed.map(identity), [a, b].map(identity));
});

test('a node is unfinished until each wanted skill is locked and hashed as staged, and each removed one gone', () => {
  const prepared = { wanted: [{ skill: 'lint', source: 'acme/tools', ref: 'v1', hash: 'h1' }], remove: ['old'] };
  const installed = { lint: entry(TOOLS) };
  const held = (hash, present = false) => () => ({ present, complete: true, hash: () => hash });
  assert.equal(unfinished('.', prepared, installed, held('h1')), null);
  assert.match(unfinished('.', prepared, {}, held('h1')), /lint: installation incomplete/);
  assert.match(unfinished('.', prepared, { lint: entry(TOOLS, { ref: 'v0' }) }, held('h1')),
    /lint: installation incomplete/);
  assert.match(unfinished('.', prepared, installed, held('h2')), /lint: installation incomplete/);
  assert.match(unfinished('.', prepared, { lint: entry(TOOLS, { computedHash: 'h2' }) }, held('h2')),
    /lint: installation incomplete/);
  assert.match(unfinished('.', prepared, installed, () => ({ present: true, complete: false, hash: () => 'h1' })),
    /lint: installation incomplete/);
  assert.match(unfinished('.', prepared, { ...installed, old: entry(TOOLS) }, held('h1')),
    /old: removal incomplete/);
  assert.match(unfinished('.', { ...prepared, wanted: [] }, {}, held(null, true)),
    /old: removal incomplete/);
});
