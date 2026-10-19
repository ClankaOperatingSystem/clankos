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
printf ':PROPERTIES:\n:ID: intray\n:END:\n#+TITLE: Intray\n\n* Unsorted\n' > intray.org
for slot in capture start-up wrap-up; do
    mkdir -p ".agents/skills/$slot"
    printf '#!/bin/sh\nprintf "Owned slot.\\n"\n' > "bin/$slot"
    chmod +x "bin/$slot"
    printf '%s\n' '---' "name: $slot" 'description: Owned fixture slot.' '---' > ".agents/skills/$slot/SKILL.md"
done
git add . && git commit -qm 'Create owned slots'
"$bundle" clankos-run install > "$work/out" 2> "$work/err"
install_status=$?
check 'external bundle installs through both images' test "$install_status" -eq 0
if [ "$install_status" -ne 0 ]; then cat "$work/out"; fi
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
check 'capture leaves wrappers absent in a fresh clone' test ! -e .clankos/auto
mkdir -p "$work/mock-bin" "$work/calls"
cp "$repo/test/lib/fake-docker" "$work/mock-bin/docker"
chmod +x "$work/mock-bin/docker"
export PATH="$work/mock-bin:$PATH" DOCKER_ARGS="$work/args" DOCKER_STDIN="$work/stdin" DOCKER_LOG="$work/calls"
cd "$work" || exit 1
python3 - <<'SOCKET'
import socket
with socket.socket(socket.AF_UNIX) as agent:
    agent.bind('agent.sock')
SOCKET
cd "$work/clone" || exit 1
CLANKOS_IMAGE=example/clankos:root CLANKOS_SKILLS_IMAGE= GH_TOKEN=fixture-token SSH_AUTH_SOCK="$work/agent.sock" "$bundle" clankos-run install > "$work/out" 2> "$work/err"
check 'nested dispatcher completes installer orchestration' test $? -eq 0
check 'only Node receives installer credentials' python3 - "$DOCKER_LOG" <<'CHECK'
import pathlib, sys
root = pathlib.Path(sys.argv[1]); count = int((root / 'count').read_text())
calls = [(root / str(i)).read_bytes().split(b'\0')[:-1] for i in range(count - 2, count + 1)]
for call in (calls[0], calls[2]):
    assert b'GH_TOKEN' not in call
    assert not any(b'SSH_AUTH_SOCK' in arg for arg in call)
assert b'GH_TOKEN' in calls[1]
assert b'SSH_AUTH_SOCK=/tmp/ssh-agent.sock' in calls[1]
assert b'example/clankos-skills:root' in calls[1]
CHECK
[ "$failures" -eq 0 ]
