#!/usr/bin/env bash
# The tree: a root, its responsibilities and their projects and
# products, and the mounts among them.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
. "$repo/test/lib/model.sh"
image_remote
. "$repo/test/lib/sources.sh"

check "A tree is a root, the responsibilities beneath it, and each one's projects and products." \
    ert pos-corpus/a-nodes-place-says-what-it-is
check "A node is a responsibility or a project that has a configuration of its own." \
    ert pos-corpus/a-configured-directory-is-a-responsibility-that-owns-what-lies-beneath
check "A mount is a node or a product that is a repository of its own." \
    ert pos-corpus/a-configured-repository-is-read-and-not-written
check "A walk of the tree reads a mount's files." \
    ert pos-corpus/a-configured-repository-is-read-and-not-written
check "No command run above a mount writes a mount's files." \
    ert pos-corpus/a-configured-repository-is-read-and-not-written

# A garden with a responsibility mounted in it, which declares a
# methodology of its own. The garden holds a file the lint reports.
origin adr v1 adr-record
mkdir -p "$work/child/.clanka" && cd "$work/child" && git init -q -b master
configure "$(declared adr v1)"
printf ':PROPERTIES:\n:ID: %s\n:END:\n#+TITLE: Intray\n\n* Unsorted\n' child-intray > intray.org
git add . && git commit -qm 'Add a responsibility'
garden
printf 'pos: 2\nbin: bin\nchildren:\n  - path: child\n    remote: %s\n' "$work/child" > .clanka/config.yml
printf '#+TITLE: No identifier\n' > stray.org
git add . && git commit -qm 'Mount a responsibility'
git clone -q "$work/child" child

(cd child && "$bin/clankos-run" install > "$work/out" 2> "$work/err")
"$bin/clankos-run" install > "$work/out" 2> "$work/err"
check "A mount has a configuration, an install and a lock of its own." \
    sh -c 'test -f child/.agents/skills/adr-record/SKILL.md \
        && grep -q "\"adr-record\"" child/skills-lock.json \
        && test ! -e .agents/skills/adr-record \
        && ! grep -q "\"adr-record\"" skills-lock.json'
"$bin/clankos-run" pos-lint > "$work/above" 2>&1
(cd child && "$bin/clankos-run" pos-lint > "$work/within" 2>&1)
check "A command run in a mount works on that mount and never looks upward." \
    sh -c 'grep -q stray.org "$0/above" && ! grep -q stray.org "$0/within"' "$work"

[ "$failures" -eq 0 ]
