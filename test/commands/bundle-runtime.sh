#!/usr/bin/env bash
# Run an isolated bundle against the image, without host wrappers.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
export DOCKER_HOST=${DOCKER_HOST:-$(docker context inspect --format '{{.Endpoints.docker.Host}}')}
export XDG_CONFIG_HOME="$work/config" HOME="$work/home"
unset CLANKOS_WORKSPACE
mkdir -p "$HOME" 'bundle store' 'target garden/.clankos'
cp -R "$repo/skills/clankos-lint" 'bundle store/lint'
bundle="$work/bundle store/lint/scripts/clankos"
git -C 'target garden' init -q
printf 'pos: 2\nprojects: projects/\n' > 'target garden/.clankos/config.yml'
cd 'target garden' || exit 1
printf '#+TITLE: Intray\n\n* Unsorted\n' > intray.org
printf '#+TITLE: Journal\n' > journal.org
mkdir archives
check 'target begins without host wrappers' test ! -e .clankos/auto/bin
printf '** NEXT Fixture lint\n' >> intray.org
"$bundle" pos-lint > "$work/out" 2> "$work/err"
check 'isolated bundle reaches lint before wrappers exist' test $? -eq 1
check 'lint reports the seeded finding' grep -qx 'intray.org:4: NEXT item in the intray: clarified, to be placed' "$work/out"
printf '#+TITLE: Intray\n\n* Unsorted\n' > intray.org
"$bundle" capture -- 'Fixture capture' > "$work/out" 2> "$work/err"
check 'isolated bundle reaches capture in the image' test $? -eq 0
cat "$work/err"
check 'runtime writes the target intray' grep -q 'Fixture capture' intray.org
"$bundle" start-up --view intray > "$work/out" 2> "$work/err"
check 'isolated bundle reaches start-up in the image' test $? -eq 0
cat "$work/err"
check 'start-up reads the captured task' grep -q 'Fixture capture' "$work/out"
printf 'Fixture handover.\n' | "$bundle" wrap-up -- 'Fixture session' > "$work/out" 2> "$work/err"
check 'isolated bundle passes handover stdin to the image' test $? -eq 0
cat "$work/err"
check 'wrap-up returns a content citation' grep -q 'ipfs://' "$work/out"
cd "$work" || exit 1
mkdir -p 'main garden/.clankos'
printf 'pos: 2\nprojects: projects/\n' > 'main garden/.clankos/config.yml'
printf '#+TITLE: Intray\n\n* Unsorted\n' > 'main garden/intray.org'
git -C 'main garden' init -qb master
git -C 'main garden' add .
git -C 'main garden' -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm 'Create fixture'
git -C 'main garden' worktree add -qb linked "$work/linked garden"
cp 'main garden/intray.org' "$work/main-intray"
cd 'linked garden' || exit 1
"$bundle" capture -- 'Linked fixture' > "$work/out" 2> "$work/err"
check 'linked worktree reaches capture' test $? -eq 0
cat "$work/err"
check 'linked intray changes' grep -q 'Linked fixture' intray.org
check 'main worktree remains unchanged' cmp -s "$work/main-intray" "$work/main garden/intray.org"
check 'refresh writes common Git exclusions' grep -q '/.clankos/auto' "$work/main garden/.git/info/exclude"

# Substitute a runtime operation to observe bytes after Docker and run.
export REAL_DOCKER=$(command -v docker) PROBE_SCRIPT="$work/runtime-probe"
mkdir -p "$work/probe-bin" deep
cat > "$PROBE_SCRIPT" <<'PROBE'
#!/bin/sh
printf '%s\0' "$@" > probe-args
cat > probe-stdin
git rev-parse --show-toplevel > probe-root || exit 98
common=$(git rev-parse --git-common-dir) || exit 98
if (printf 'must not write\n' >> "$common/config") 2>/dev/null; then exit 99; fi
printf 'probe stdout\n'
printf 'probe stderr\n' >&2
exit 37
PROBE
chmod +x "$PROBE_SCRIPT"
cat > "$work/probe-bin/docker" <<'DOCKER'
#!/usr/bin/env bash
[ "$1" = run ] || exit 2
shift
exec "$REAL_DOCKER" run -v "$PROBE_SCRIPT:/usr/local/libexec/clankos/pos-lint:ro" "$@"
DOCKER
chmod +x "$work/probe-bin/docker"
cd deep || exit 1
printf 'input\0bytes\n' > "$work/probe-input"
PATH="$work/probe-bin:$PATH" "$bundle" pos-lint '' 'a b' '*' -- $'line\nbreak' < "$work/probe-input" > "$work/out" 2> "$work/err"
check 'runtime probe preserves exit status and cannot write Git config' test $? -eq 37
check 'runtime probe preserves stdin bytes' cmp -s "$work/probe-input" probe-stdin
check 'runtime probe sees exact argv' python3 - <<'CHECK'
from pathlib import Path
assert Path('probe-args').read_bytes() == b'\0a b\0*\0--\0line\nbreak\0'
CHECK
check 'Git resolves linked root inside container' grep -qxF "$work/linked garden" probe-root
check 'runtime stdout remains separate' grep -qx 'probe stdout' "$work/out"
check 'runtime stderr remains separate' grep -qx 'probe stderr' "$work/err"
[ "$failures" -eq 0 ]
