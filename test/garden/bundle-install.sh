#!/usr/bin/env bash
# Install from an external bundle, retain owned slots, then run a fresh clone.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
image_remote
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=Fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
mkdir -p 'bundle store' garden/.clankos garden/bin
cp -R "$repo/skills/clankos-lint" 'bundle store/lint'
bundle="$work/bundle store/lint/scripts/clankos"
cd garden || exit 1
git init -qb master
printf 'pos: 2\nprojects: projects/\nbin: bin\n' > .clankos/config.yml
printf '#+TITLE: Intray\n\n* Unsorted\n' > intray.org
for slot in capture start-up wrap-up; do
    mkdir -p ".agents/skills/$slot"
    printf '#!/bin/sh\nprintf "Owned slot.\\n"\n' > "bin/$slot"
    chmod +x "bin/$slot"
    printf '%s\n' '---' "name: $slot" 'description: Owned fixture slot.' '---' > ".agents/skills/$slot/SKILL.md"
done
git add . && git commit -qm 'Create owned slots'
"$bundle" clankos-run install > "$work/out" 2> "$work/err"
check 'external bundle installs through both images' test $? -eq 0
cat "$work/err"
for slot in capture start-up wrap-up; do
    check "$slot command remains owned" git diff --quiet -- "bin/$slot"
    check "$slot skill remains owned" git diff --quiet -- ".agents/skills/$slot/SKILL.md"
done
for resource in clankos clankos-install capture start-up wrap-up; do
    check "installed $resource matches release source" cmp -s ".agents/skills/clankos-lint/scripts/$resource" "$repo/skills/clankos-lint/scripts/$resource"
done
git add . && git commit -qm 'Install bundles'
git clone -q . ../clone
cd ../clone || exit 1
check 'fresh clone has no ignored wrappers' test ! -e .clankos/auto/bin
.agents/skills/clankos-lint/scripts/clankos capture -- 'Fresh clone task' > "$work/out" 2> "$work/err"
check 'installed bundle runs from fresh clone' test $? -eq 0
cat "$work/err"
check 'explicit bundle bypasses owned slot command' grep -q 'Fresh clone task' intray.org
check 'refresh reconstructs wrappers after startup' test -x .clankos/auto/bin/clankos-run
[ "$failures" -eq 0 ]
