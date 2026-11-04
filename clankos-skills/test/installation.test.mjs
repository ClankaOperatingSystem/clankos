// Run: make check. The file checks of installation.mjs, on the host,
// each in a node made in a temporary directory.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readdirSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { atomic, boundary, hash, locks, paths, read } from '../installation.mjs';

// Run body with a new directory holding files, each [path, text].
function inNode(files, body) {
  const node = mkdtempSync(join(tmpdir(), 'clankos-skills-test-'));
  try {
    for (const [path, text] of files) {
      mkdirSync(join(node, path, '..'), { recursive: true });
      writeFileSync(join(node, path), text);
    }
    body(node);
  } finally {
    rmSync(node, { recursive: true, force: true });
  }
}

const lock = (skills) => JSON.stringify({ version: 1, skills });

test('a lock is read when it is version 1 and each entry names its source', () => {
  inNode([['skills-lock.json', lock({ lint: { source: 'acme/tools' } })]], (node) => {
    assert.deepEqual(locks(node), { lint: { source: 'acme/tools' } });
  });
  inNode([], (node) => assert.deepEqual(locks(node), {}));
  for (const bad of [
    JSON.stringify({ version: 2, skills: {} }),
    lock({ Lint: { source: 'acme/tools' } }),
    lock({ lint: { source: '' } }),
    lock({ lint: { source: 'acme/tools', sourceUrl: 1 } }),
  ]) {
    inNode([['skills-lock.json', bad]], (node) => assert.throws(() => locks(node), /invalid skills lock/));
  }
});

test('a folder\'s hash depends on its paths and bytes, and not on the order they are made', () => {
  inNode([['a/SKILL.md', 'x'], ['a/b/c', 'y'], ['z/b/c', 'y'], ['z/SKILL.md', 'x']], (node) => {
    assert.equal(hash(join(node, 'a')), hash(join(node, 'z')));
    rmSync(join(node, 'z/b'), { recursive: true });
    writeFileSync(join(node, 'z/c'), 'y');
    assert.notEqual(hash(join(node, 'a')), hash(join(node, 'z')));
    writeFileSync(join(node, 'a/b/c'), 'w');
    assert.notEqual(hash(join(node, 'a')), hash(join(node, 'z/b')));
    assert.equal(hash(join(node, 'missing')), null);
  });
});

test('a skill holding a link or a repository is not hashed', () => {
  inNode([['a/SKILL.md', 'x']], (node) => {
    symlinkSync('SKILL.md', join(node, 'a/link'));
    assert.throws(() => hash(join(node, 'a')), /symbolic skill content/);
  });
  inNode([['a/SKILL.md', 'x'], ['a/.git/HEAD', '']], (node) => {
    assert.throws(() => hash(join(node, 'a')), /nested skill repository/);
  });
});

test('a path stays within the node: no .., no link and no repository on the way', () => {
  inNode([['home/notes.org', ''], ['mounted/.git/HEAD', '']], (node) => {
    assert.equal(boundary(node, 'home'), join(node, 'home'));
    assert.equal(boundary(node, '.'), node);
    assert.throws(() => boundary(node, '../outside'), /invalid relative path/);
    assert.throws(() => boundary(node, 'mounted/sub'), /nested repository/);
    symlinkSync('home', join(node, 'linked'));
    assert.throws(() => boundary(node, 'linked'), /symbolic link/);
  });
});

test('a harness directory may be a link to .agents/skills and to nothing else', () => {
  const dirs = ['.agents/skills', '.claude/skills'];
  inNode([['.agents/skills/lint/SKILL.md', ''], ['elsewhere/x', '']], (node) => {
    mkdirSync(join(node, '.claude'));
    symlinkSync('../.agents/skills', join(node, '.claude/skills'));
    paths(node, ['lint'], dirs);
    rmSync(join(node, '.claude/skills'));
    symlinkSync('../elsewhere', join(node, '.claude/skills'));
    assert.throws(() => paths(node, ['lint'], dirs), /symbolic harness directory/);
    assert.throws(() => paths(node, ['Lint'], dirs), /invalid skill name/);
  });
});

test('a skill in .agents/skills may not be a link, even one to itself', () => {
  for (const target of ['../../elsewhere', 'lint']) {
    inNode([['elsewhere/SKILL.md', '']], (node) => {
      mkdirSync(join(node, '.agents/skills'), { recursive: true });
      symlinkSync(target, join(node, '.agents/skills/lint'));
      assert.throws(() => paths(node, ['lint'], ['.agents/skills']), /symbolic skill/);
    });
  }
});

test('a file written atomically holds the new text, and nothing is left beside it', () => {
  inNode([['state.json', 'old']], (node) => {
    atomic(join(node, 'state.json'), 'new');
    assert.equal(read(join(node, 'state.json')), 'new');
    assert.deepEqual(readdirSync(node), ['state.json']);
    assert.equal(read(join(node, 'missing')), null);
  });
});
