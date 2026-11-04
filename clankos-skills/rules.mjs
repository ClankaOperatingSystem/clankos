// The rules install and apply-v1 follow, as functions of what they are
// given: a node's configuration, its lock, the identities ClankOS
// manages and what the skills CLI staged. They read and change nothing;
// install.mjs and apply.mjs do, and pass in what they read. The tests
// in test/ run them on the host.

// The skills a repository may fill with a skill of its own.
export const SLOTS = ['capture', 'start-up', 'wrap-up'];

// The text two sources are compared by, as poslib's source key.
export const key = (source) => source.replace(/\/$/, '').replace(/\.git$/, '')
  .replace(/^https:\/\/github\.com\//, '');

// The source key of a lock entry.
export const entryKey = (entry) => key(typeof entry.sourceUrl === 'string' && entry.sourceUrl
  ? entry.sourceUrl : String(entry.source));

// A managed identity: the skill a node has from a source.
export const identity = (entry) => JSON.stringify([entry.node, key(entry.source), entry.skill]);

// 1. The refusal of a source's ref, or null. refs are the names git
// ls-remote lists for the source. A ref is a tag or a full commit id,
// and never a branch.
export function refRefusal(source, refs) {
  if (/^[0-9a-f]{40}$/.test(source.ref) || refs.includes(`refs/tags/${source.ref}`)) return null;
  if (refs.includes(`refs/heads/${source.ref}`)) {
    return `${source.source}: ${source.ref} is a branch; give a tag or a commit`;
  }
  return `${source.source}: ${source.ref} is no tag; a commit is given by its forty-digit id`;
}

// Who owns each skill the lock records. explicit is apply-v1's mode,
// where ownership is the managed identities; otherwise a skill is
// ClankOS's when its source is declared, or uninstall names it. seed is
// apply-v1's first run, with no saved state: then a skill from a
// declared source is owned. A skill no rule owns is wild-caught, put
// there with the skills CLI, and left as it is.
export function owners({ explicit, sources, locked, managed = [], uninstall = [], seed = false }) {
  const declared = new Set(sources.map((source) => key(source.source)));
  const removing = new Set(uninstall);
  const owned = (name, entry) => managed.find((each) => each.skill === name
    && key(each.source) === entryKey(entry));
  const keep = (name, entry) => explicit && owned(name, entry)?.disposition === 'keep';
  const wild = (name) => name in locked && (explicit
    ? !owned(name, locked[name]) && !(seed && declared.has(entryKey(locked[name])))
    : !declared.has(entryKey(locked[name])) && !removing.has(name));
  return { declared, owned, keep, wild };
}

// 3. The refusals of the names the sources supply. supplied is each
// source with the names and lock entries it staged. inspect(name) says
// what the node holds at .agents/skills/NAME: present, whether anything
// is there; linked, whether it is a link ClankOS's refresh made;
// filled(), whether the repository's bin tracks a command of the name;
// and hash(), the folder's hash, which may throw.
export function nameRefusals(supplied, { explicit, clankos, locked, managed = [], wild, inspect }) {
  const refused = [];
  const by = new Map();
  for (const { source, names, staged = {} } of supplied) {
    for (const name of names) {
      const held = inspect(name);
      if (wild(name) && !(explicit && entryKey(locked[name]) === key(source.source))) {
        refused.push(`${name}: installed from ${locked[name].source}, which the configuration`
          + ` does not declare, and supplied by ${source.source}; remove one`);
        continue;
      }
      let ours = name in locked || held.linked;
      if (explicit && held.present && !ours && managed.some((entry) => entry.skill === name
          && key(entry.source) === key(source.source))) {
        try { ours = held.hash() === staged[name].computedHash; }
        catch (error) { refused.push(error.message); }
      }
      if (source.kind === 'methodology' && !name.startsWith(`${source.name}-`)) {
        refused.push(`${name}: a skill of ${source.source} not named ${source.name}-NAME`);
      }
      if (name.startsWith('clankos-') && key(source.source) !== clankos) {
        refused.push(`${name}: the name clankos is reserved, and ${source.source} supplies it`);
      }
      if (by.has(name)) {
        refused.push(`${name}: supplied by ${by.get(name)} and by ${source.source}`);
      }
      by.set(name, source.source);
      if (SLOTS.includes(name) && ((held.present && !ours) || held.filled())) {
        refused.push(`${name}: the repository fills this slot itself`);
      } else if (held.present && !ours) {
        refused.push(`${name}: the repository has a skill of its own of this name`);
      }
    }
  }
  return refused;
}

// What the sources supply: each name's source, the harnesses it is
// linked for and, in apply-v1, the hash the skills CLI recorded.
export function wanted(supplied, explicit) {
  const sources = new Map();
  const links = new Map();
  const hashes = new Map();
  for (const { source, names, links: linked, staged = {} } of supplied) {
    for (const name of names) {
      sources.set(name, source);
      links.set(name, linked.get(name));
      if (explicit) hashes.set(name, staged[name].computedHash);
    }
  }
  return { sources, links, hashes };
}

// 4. Whether the installed skill name, recorded in the lock as entry,
// is to be removed: it is no longer declared, is declared at another
// ref or source, is linked for other harnesses, or, in apply-v1, has no
// SKILL.md or another hash. A kept or wild-caught skill is not.
// installedLinks are the harnesses each installed skill is linked for,
// and complete(name) whether the node's folder has a SKILL.md.
export function changing(name, entry, { explicit, want, keep, wild, installedLinks, complete }) {
  const source = want.sources.get(name);
  if (explicit && !source && keep(name, entry)) return false;
  if (!source && wild(name)) return false;
  return !(source && entryKey(entry) === key(source.source) && entry.ref === source.ref
    && installedLinks.get(name) === want.links.get(name)
    && (!explicit || (complete(name) && want.hashes.get(name) === entry.computedHash)));
}

// In apply-v1, the hash of each installed skill that is wanted or
// changes, as it is now. A skill whose hash is not the one the lock
// recorded has local changes, and a managed skill with files and no lock
// entry cannot be shown to be removed: either is refused, and the node
// is not changed. inspect(name) says of .agents/skills/NAME whether it
// is present, and hash(), its hash.
export function untouched({ locked, wanted, isChanging, managed, inspect }) {
  const actual = {};
  for (const [name, entry] of Object.entries(locked)) {
    if (!wanted.has(name) && !isChanging(name, entry)) continue;
    actual[name] = inspect(name).hash();
    if (actual[name] !== null && actual[name] !== entry.computedHash) {
      throw Error(`${name}: local changes or no recorded hash; restore or keep the skill before applying`);
    }
  }
  for (const entry of managed) {
    if (!(entry.skill in locked) && !wanted.has(entry.skill)
        && entry.disposition !== 'keep' && inspect(entry.skill).present) {
      throw Error(`${entry.skill}: managed files have no lock entry; removal cannot be verified`);
    }
  }
  return actual;
}

// The preparation apply-v1's preflight records for a node, and checks
// again before the node is changed.
export function preparation({ locked, want, isChanging, owned, seed, declared, actual }) {
  return {
    wanted: [...want.sources].map(([skill, source]) => ({
      skill, source: key(source.source), ref: source.ref, hash: want.hashes.get(skill),
    })),
    remove: Object.entries(locked).filter(([name, entry]) => isChanging(name, entry))
      .map(([name]) => name),
    locked,
    actual,
    owned: Object.entries(locked)
      .filter(([name, entry]) => owned(name, entry) || (seed && declared.has(entryKey(entry))))
      .map(([skill, entry]) => ({ skill, source: entryKey(entry) })),
  };
}

// The managed identities apply-v1 saves. pending, before any node
// changes: those every node had, and each prepared node's owned and
// wanted skills. done, after every node has changed: the wanted ones.
// work is each node's path with its preparation.
export function ownership(nodes, work) {
  const managed = new Map();
  const done = new Map();
  for (const node of nodes) for (const entry of node.managed) managed.set(identity(entry), entry);
  for (const { path, prepared } of work) {
    const own = (entry) => ({ node: path, source: key(entry.source), skill: entry.skill, disposition: null });
    for (const entry of [...prepared.owned, ...prepared.wanted]) {
      if (!managed.has(identity(own(entry)))) managed.set(identity(own(entry)), own(entry));
    }
    for (const entry of prepared.wanted) done.set(identity(own(entry)), own(entry));
  }
  return { pending: [...managed.values()], done: [...done.values()] };
}

// The text of the installation state that holds entries.
export const serialize = (entries) => JSON.stringify({
  schema: 1,
  managed: [...entries].sort((a, b) => identity(a).localeCompare(identity(b))),
}) + '\n';

// Why a node's application is unfinished, or null. installed is its
// lock after the installer ran; inspect(name) says of the folder
// .agents/skills/NAME whether it has a SKILL.md, complete, whether it
// is present, and hash(), its hash.
export function unfinished(path, prepared, installed, inspect) {
  for (const entry of prepared.wanted) {
    const actual = installed[entry.skill];
    const held = inspect(entry.skill);
    if (!actual || entryKey(actual) !== entry.source || actual.ref !== entry.ref
        || actual.computedHash !== entry.hash || !held.complete
        || held.hash() !== actual.computedHash) {
      return `${path}/${entry.skill}: installation incomplete; repeat apply-v1`;
    }
  }
  for (const name of prepared.remove) {
    if (!prepared.wanted.some((entry) => entry.skill === name)
        && (installed[name] || inspect(name).present)) {
      return `${path}/${name}: removal incomplete; repeat apply-v1`;
    }
  }
  return null;
}
