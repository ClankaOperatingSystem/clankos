#!/usr/bin/env bash
# Exercise one isolated installed bundle without auto/bin or Docker.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
unset CLANKOS_WORKSPACE CLANKOS_IMAGE
export XDG_CONFIG_HOME="$work/config" HOME="$work/home"
mkdir -p calls 'bundle store' 'target garden/child/deep' mock-bin "$HOME"
cp -R "$repo/skills/clankos-lint" 'bundle store/lint'
bundle="$work/bundle store/lint/scripts/clankos"
git -C 'target garden' init -q
mkdir -p 'target garden/.clankos' 'target garden/child/.clankos'
printf 'pos: 2\nimage: example/clankos:root\n' > 'target garden/.clankos/config.yml'
printf 'pos: 2\nimage: example/clankos:child\n' > 'target garden/child/.clankos/config.yml'
cat > mock-bin/docker <<'MOCK'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$DOCKER_ARGS"
count=$(cat "$DOCKER_LOG/count" 2>/dev/null || echo 0)
count=$((count + 1))
printf '%s' "$count" > "$DOCKER_LOG/count"
cp "$DOCKER_ARGS" "$DOCKER_LOG/$count"
cat > "$DOCKER_STDIN"
printf 'runtime stdout\n'
printf 'runtime stderr\n' >&2
exit "${DOCKER_STATUS:-0}"
MOCK
chmod +x mock-bin/docker
export PATH="$work/mock-bin:$PATH" DOCKER_ARGS="$work/args" DOCKER_STDIN="$work/stdin" DOCKER_LOG="$work/calls"
cd 'target garden/child/deep' || exit 1
check 'external bundle selects caller workspace and nested image' \
    test "$("$bundle" --show)" = "workspace $work/target garden
image example/clankos:child"
printf 'input\0bytes\n' > "$work/input"
"$bundle" pos-lint '' 'a b' '*' -- "quote'\"" $'line\nbreak' < "$work/input" > "$work/out" 2> "$work/err"
check 'external bundle reaches runtime' test $? -eq 0
check 'stdin is unchanged' cmp -s "$work/input" "$DOCKER_STDIN"
check 'argv retains empty and special arguments' python3 - "$DOCKER_ARGS" <<'PY'
import pathlib, sys
args = pathlib.Path(sys.argv[1]).read_bytes().split(b'\0')[:-1]
expected = [b'/usr/local/libexec/clankos/run', b'pos-lint', b'', b'a b', b'*', b'--', b'quote\'"', b'line\nbreak']
assert args[-len(expected):] == expected, args
PY
check 'stdout is unchanged' grep -qx 'runtime stdout' "$work/out"
check 'stderr is unchanged' grep -qx 'runtime stderr' "$work/err"
check 'operation status is retained' status 37 env DOCKER_STATUS=37 "$bundle" pos-lint
check 'Docker failure status is retained' status 125 env DOCKER_STATUS=125 "$bundle" pos-lint
check 'nested dispatcher supports inspection' test "$("$bundle" clankos-run --show)" = "workspace $work/target garden
image example/clankos:child"
check 'slash command is refused' status 127 "$bundle" ../tool
check 'unknown command is refused' status 127 "$bundle" no-such-command
for pair in capture:pos-capture start-up:startup-prompt wrap-up:wrap-up; do
    "$bundle" "${pair%:*}" -- fixture < "$work/input" > "$work/out" 2> "$work/err"
    check "$pair reaches its runtime operation" python3 - "$DOCKER_ARGS" "${pair#*:}" <<'CHECK'
import pathlib, sys
args = pathlib.Path(sys.argv[1]).read_bytes().split(b'\0')[:-1]
assert args[-3:] == [sys.argv[2].encode(), b'--', b'fixture'], args
CHECK
    check "$pair preserves stdin" cmp -s "$work/input" "$DOCKER_STDIN"
done
cp -R "$work/bundle store/lint" "$work/relocated"
check 'relocated bundle works' status 0 "$work/relocated/scripts/clankos" --show
check 'launcher creates no auto/bin' test ! -e "$work/target garden/.clankos/auto"
for directory in .clanka .clankos .pos; do
    for suffix in yaml yml; do
        target="$work/alias-$directory-$suffix"
        mkdir -p "$target/$directory"
        git -C "$target" init -q
        printf 'pos: 2\nimage: example/clankos:alias\n' > "$target/$directory/config.$suffix"
        cd "$target" || exit 1
        check "$directory/config.$suffix selects its image" test "$("$bundle" --show)" = "workspace $target
image example/clankos:alias"
    done
done
cd "$work/target garden/child/deep" || exit 1
"$bundle" pos-lint ../task.org > "$work/out" 2> "$work/err"
check 'relative argument and caller cwd are retained' python3 - "$DOCKER_ARGS" "$PWD" <<'CHECK'
import pathlib, sys
args = pathlib.Path(sys.argv[1]).read_bytes().split(b'\0')[:-1]
assert args[-1] == b'../task.org'
assert args[args.index(b'-w') + 1] == sys.argv[2].encode()
CHECK
check 'image override wins' test "$(CLANKOS_IMAGE=example/override "$bundle" --show | tail -1)" = 'image example/override'
check 'outside workspace override is refused' status 2 env CLANKOS_WORKSPACE="$work/alias-.pos-yml" "$bundle" --show
check 'missing command exits 2' status 2 "$bundle"
check 'help runs without Docker' status 0 "$bundle" --help
for slot in capture start-up wrap-up; do
    check "$slot retains wrapper help" test "$("$bundle" "$slot" --help)" = "$("$repo/bin/$slot" --help)"
done
mkdir -p "$work/target garden/.pos"
printf 'pos: 2\n' > "$work/target garden/.pos/config.yaml"
"$bundle" --show > "$work/out" 2> "$work/err"
check 'duplicate configurations are refused before Docker' test $? -eq 2
check 'duplicate error names both files' grep -q '.clankos/config.yml.*.pos/config.yaml' "$work/err"
# Remove only the extra configuration created by this fixture.
rm "$work/target garden/.pos/config.yaml"
mkdir -p "$work/target garden/nested"
git -C "$work/target garden/nested" init -q
cd "$work/target garden/nested" || exit 1
check 'nested Git repository stops image inheritance' test "$("$bundle" --show | tail -1)" = 'image ghcr.io/clankaoperatingsystem/clankos:latest'
cd "$work" || exit 1
python3 - <<'SOCKET'
import socket
with socket.socket(socket.AF_UNIX) as agent:
    agent.bind('agent.sock')
SOCKET
cd "$work/target garden" || exit 1
GH_TOKEN=fixture-token SSH_AUTH_SOCK="$work/agent.sock" "$bundle" clankos-run install > "$work/out" 2> "$work/err"
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
git -c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty -qm 'Start fixture'
git worktree add -qb linked "$work/linked garden"
cd "$work/linked garden" || exit 1
"$bundle" pos-lint > "$work/out" 2> "$work/err"
check 'linked worktree gets bounded metadata mounts' python3 - "$DOCKER_ARGS" "$work/target garden/.git" "$work/linked garden" <<'CHECK'
import pathlib, sys
args = pathlib.Path(sys.argv[1]).read_bytes().split(b'\0')[:-1]
mounts = [args[i+1].decode() for i, arg in enumerate(args[:-1]) if arg == b'-v']
common, target = sys.argv[2:]
assert common + ':' + common + ':ro' in mounts, mounts
assert common + '/info:' + common + '/info' in mounts, mounts
assert target + ':' + target in mounts, mounts
assert not any(m.startswith(str(pathlib.Path(common).parent) + ':') for m in mounts), mounts
CHECK
"$bundle" help > "$work/out" 2> "$work/err"
check 'read-only operation receives no writable metadata' python3 - "$DOCKER_ARGS" <<'CHECK'
import pathlib, sys
args = pathlib.Path(sys.argv[1]).read_bytes().split(b'\0')[:-1]
assert not any(b'/.git/info:' in arg for arg in args)
CHECK
mkdir -p "$work/no-docker"
for program in bash dirname sed head grep; do
    ln -s "$(command -v "$program")" "$work/no-docker/$program"
done
check 'missing Docker is diagnosed' status 127 env PATH="$work/no-docker" "$bundle" pos-lint
check 'inspection needs no Docker' status 0 env PATH="$work/no-docker" "$bundle" --show
"$bundle" clankos-run help pos-lint > "$work/out" 2> "$work/err"
check 'nested dispatcher preserves runtime help arguments' python3 - "$DOCKER_ARGS" <<'CHECK'
import pathlib, sys
args = pathlib.Path(sys.argv[1]).read_bytes().split(b'\0')[:-1]
assert args[-2:] == [b'help', b'pos-lint']
CHECK
for skill in "$repo"/skills/*; do
    check "${skill##*/} contains its host resources" test -x "$skill/scripts/clankos" -a -x "$skill/scripts/clankos-install" -a -x "$skill/scripts/capture" -a -x "$skill/scripts/start-up" -a -x "$skill/scripts/wrap-up"
done
check 'generated bundle resources match their sources' "$repo/scripts/build-bundles" --check
mkdir -p "$work/build/scripts" "$work/build/skills"
cp "$repo/scripts/build-bundles" "$work/build/scripts/"
cp -R "$repo/bin" "$repo/libexec" "$work/build/"
cp -R "$repo/skills/clankos-lint" "$work/build/skills/"
check 'bundle generation succeeds' "$work/build/scripts/build-bundles"
check 'repeat generation retains exact bytes and modes' "$work/build/scripts/build-bundles" --check
printf '\nchanged\n' >> "$work/build/skills/clankos-lint/scripts/clankos"
check 'stale generated launcher is detected' status 1 "$work/build/scripts/build-bundles" --check
[ "$failures" -eq 0 ]
