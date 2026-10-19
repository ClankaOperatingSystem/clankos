// Files and identities used by explicit repository application.
import { createHash, randomUUID } from 'node:crypto';
import { lstatSync, readFileSync, readdirSync, readlinkSync, renameSync,
  rmSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const key = (source) => source.replace(/\/$/, '').replace(/\.git$/, '')
  .replace(/^https:\/\/github\.com\//, '');
export const entryKey = (entry) => key(entry.sourceUrl || entry.source);
export const identity = (entry) => JSON.stringify([entry.node, key(entry.source), entry.skill]);
export const stat = (path) => {
  try { return lstatSync(path); } catch (error) { if (['ENOENT', 'ENOTDIR'].includes(error.code)) return null; throw error; }
};
export const read = (path) => stat(path) ? readFileSync(path, 'utf8') : null;

export function boundary(root, path) {
  if (path !== '.' && (!path || path.split('/').some((part) => ['', '.', '..'].includes(part)))) {
    throw Error(`invalid relative path: ${path}`);
  }
  let dir = root;
  if (path !== '.') for (const part of path.split('/')) {
    dir = join(dir, part);
    if (stat(dir)?.isSymbolicLink()) throw Error(`symbolic link: ${dir}`);
    if (stat(join(dir, '.git'))) throw Error(`nested repository: ${dir}`);
  }
  return dir;
}

export function locks(node) {
  const file = join(node, 'skills-lock.json');
  if (stat(file)?.isSymbolicLink()) throw Error(`symbolic skills lock: ${file}`);
  if (!stat(file)) return {};
  const data = JSON.parse(read(file));
  if (data?.version !== 1 || !data.skills || typeof data.skills !== 'object'
      || Array.isArray(data.skills) || Object.entries(data.skills).some(([name, entry]) =>
        !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(name) || !entry || typeof entry.source !== 'string'
        || !entry.source || (entry.sourceUrl !== undefined && typeof entry.sourceUrl !== 'string'))) {
    throw Error(`invalid skills lock: ${file}`);
  }
  return data.skills;
}

// This is the skills CLI's folder hash: sorted relative paths and file bytes.
export function hash(dir) {
  if (!stat(dir)) return null;
  const files = [];
  function collect(path) {
    if (stat(join(path, '.git'))) throw Error(`nested skill repository: ${path}`);
    for (const entry of readdirSync(path, { withFileTypes: true })) {
      const full = join(path, entry.name);
      if (entry.isSymbolicLink()) throw Error(`symbolic skill content: ${full}`);
      if (entry.isDirectory() && !['.git', 'node_modules'].includes(entry.name)) collect(full);
      else if (entry.isFile()) files.push(relative(dir, full));
    }
  }
  collect(dir);
  const digest = createHash('sha256');
  for (const file of files.sort((a, b) => a.localeCompare(b))) {
    digest.update(file); digest.update(readFileSync(join(dir, file)));
  }
  return digest.digest('hex');
}

// The pinned skills CLI supplies this list when its image is built.
const agentPaths = JSON.parse(readFileSync(new URL('./agent-paths.json', import.meta.url), 'utf8'));
export function paths(node, names) {
  if (names.some((name) => !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(name))) throw Error('invalid skill name');
  boundary(node, '.agents/skills');
  for (const dir of agentPaths) {
    const parent = dirname(dir);
    boundary(node, parent);
    const folder = join(node, dir);
    if (stat(folder)?.isSymbolicLink()) {
      if (resolve(dirname(folder), readlinkSync(folder)) !== join(node, '.agents/skills')) {
        throw Error(`symbolic harness directory: ${folder}`);
      }
    } else boundary(node, dir);
    for (const name of names) {
      const path = join(folder, name);
      if (stat(path)?.isSymbolicLink()) {
        if (dir === '.agents/skills'
            || resolve(dirname(path), readlinkSync(path)) !== join(node, '.agents/skills', name)) {
          throw Error(`symbolic skill: ${path}`);
        }
      } else if (stat(join(path, '.git'))) throw Error(`nested skill repository: ${path}`);
    }
  }
}

export function atomic(file, text) {
  if (read(file) === text) return;
  const temporary = `${file}.${randomUUID()}`;
  try {
    writeFileSync(temporary, text, { mode: stat(file)?.mode & 0o777 || 0o600, flag: 'wx' });
    renameSync(temporary, file);
  } finally { rmSync(temporary, { force: true }); }
}
export const installer = fileURLToPath(new URL('./install.mjs', import.meta.url));
