#!/usr/bin/env bash
# Plan configured and formerly managed nodes without changing the garden.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
mkdir -p garden/.clankos garden/area/.pos garden/projects/one/.clanka
cd garden || exit 1
git init -q
printf 'pos: 2\nprojects: projects/\nchildren:\n  - path: area\n  - path: vendor\n' > .clankos/config.yml
printf 'pos: 2\n' > area/.pos/config.yaml
printf 'pos: 2\n' > projects/one/.clanka/config.yml
mkdir vendor
git -C vendor init -q
mkdir vendor/.pos
printf 'not valid YAML: [' > vendor/.pos/config.yaml
plan() {
    "$bin/clankos-run" installation-plan > "$work/out" 2> "$work/err"
    local result=$?
    if [ "$result" -ne 0 ]; then cat "$work/err"; fi
    return "$result"
}
status() {
    local expected=$1 result
    shift
    "$@" > "$work/status-out" 2> "$work/status-err"
    result=$?
    if [ "$result" -ne "$expected" ]; then
        echo "expected exit $expected, got $result"
        cat "$work/status-out" "$work/status-err"
        return 1
    fi
}
check 'plan succeeds without reading a nested repository' plan
cat "$work/err"
check 'plan includes local children and projects' python3 - "$work/out" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert [n['path'] for n in p['nodes']] == ['.', 'area', 'projects/one']
assert p['skipped'] == ['vendor']
assert all(n['status']=='configured' for n in p['nodes'])
PY
check 'planning does not refresh wrappers' test ! -e .clankos/auto
check 'planning does not install skills' test ! -e .agents
check 'planning does not create state' test ! -e .clankos/installation-state.json
mkdir -p old/.pos
printf 'not valid YAML: [' > old/.pos/config.yaml
cat > .clankos/installation-state.json <<'JSON'
{"schema":1,"managed":[
 {"node":"old","source":"example/method","skill":"method-one","disposition":"keep"},
 {"node":"gone","source":"example/method","skill":"method-two","disposition":"remove"},
 {"node":"vendor","source":"example/method","skill":"method-three","disposition":null}
]}
JSON
check 'plan retains cleanup nodes and saved choices' plan
check 'cleanup stops at a new repository and handles missing nodes' python3 - "$work/out" <<'PY'
import json,sys
nodes={n['path']:n for n in json.load(open(sys.argv[1]))['nodes']}
assert nodes['old']['status']=='cleanup'
assert nodes['old']['managed'][0]['disposition']=='keep'
assert nodes['gone']['status']=='missing'
assert nodes['gone']['managed'][0]['disposition']=='remove'
assert nodes['vendor']['status']=='blocked'
PY
cp .clankos/installation-state.json "$work/state"
check 'repeated planning succeeds' plan
check 'planning leaves saved state unchanged' cmp -s .clankos/installation-state.json "$work/state"
printf '{"schema":1,"managed":[{"node":"../outside","source":"x/y","skill":"one","disposition":null}]}' > .clankos/installation-state.json
check 'state cannot escape the repository' status 1 "$bin/clankos-run" installation-plan
printf '{broken' > .clankos/installation-state.json
check 'malformed state is refused' status 1 "$bin/clankos-run" installation-plan
printf '{"schema":2,"managed":[]}' > .clankos/installation-state.json
check 'unknown state schema is refused' status 1 "$bin/clankos-run" installation-plan
printf '{"schema":1,"managed":[]}' > .clankos/installation-state.json
mkdir -p "$work/outside/.pos"
printf 'pos: 2\n' > "$work/outside/.pos/config.yaml"
ln -s "$work/outside" escape
printf 'pos: 2\nchildren:\n  - path: escape\n' > .clankos/config.yml
check 'configured symlink escape is refused' status 1 "$bin/clankos-run" installation-plan
printf 'pos: 2\nchildren:\n  - path: vendor/deep\n' > .clankos/config.yml
check 'a path through a nested repository is skipped' plan
check 'intermediate repository is a boundary' python3 - "$work/out" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert [n['path'] for n in p['nodes']]==['.']
assert p['skipped']==['vendor/deep']
PY
printf 'pos: 2\n' > .clankos/config.yml
printf '{"schema":1,"managed":[{"node":"gone","source":"example/method","skill":"one","disposition":"drop"}]}' > .clankos/installation-state.json
check 'unknown removal intent is refused' status 1 "$bin/clankos-run" installation-plan
printf '{"schema":1,"managed":[{"node":"gone","source":"https://github.com/example/method.git","skill":"one","disposition":null},{"node":"gone","source":"example/method","skill":"one","disposition":null}]}' > .clankos/installation-state.json
check 'duplicate normalised identities are refused' status 1 "$bin/clankos-run" installation-plan
mv .clankos/installation-state.json "$work/invalid-state"
printf '{"schema":1,"managed":[]}' > "$work/outside/state.json"
ln -s "$work/outside/state.json" .clankos/installation-state.json
check 'a state symlink is refused' status 1 "$bin/clankos-run" installation-plan
rm .clankos/installation-state.json
mv .clankos/config.yml "$work/config"
ln -s "$work/outside/.pos/config.yaml" .clankos/config.yml
check 'a configuration symlink is refused' status 1 "$bin/clankos-run" installation-plan
rm .clankos/config.yml
mv "$work/config" .clankos/config.yml
printf 'pos: 2\n' > .clankos/config.yaml
check 'two configurations are refused' status 2 "$bin/clankos-run" installation-plan
rm .clankos/config.yaml
git add .clankos/config.yml
git -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm 'Create planner fixture'
git worktree add -qb linked "$work/linked"
# A read-only plan needs no writable exclusion directory in the main tree.
mv .git/info "$work/git-info"
(cd "$work/linked" && "$bin/clankos-run" installation-plan > "$work/linked-plan" 2> "$work/linked-err")
check 'linked worktree planning needs no writable metadata' test $? -eq 0
cat "$work/linked-err"
check 'linked worktree planning does not recreate exclusions' test ! -e .git/info
cd area || exit 1
check 'planning from a child refuses to widen scope' status 2 "$bin/clankos-run" installation-plan
[ "$failures" -eq 0 ]
