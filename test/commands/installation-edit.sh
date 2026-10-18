#!/usr/bin/env bash
# Save removal choices before configuration changes, without installing.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
mkdir -p garden/.clankos garden/area/.pos garden/.agents/skills/method-one
cd garden || exit 1
git init -q
cat > .clankos/config.yaml <<'YAML'
pos: 2
children:
  - path: area
methodologies:
  - source: https://github.com/example/method.git
    ref: v1
    skills: [method-one, method-two]
YAML
cp .clankos/config.yaml "$work/original"
printf 'pos: 2\n' > area/.pos/config.yaml
cat > skills-lock.json <<'JSON'
{"version":1,"skills":{
"method-one":{"source":"example/method","ref":"v1","computedHash":"unchanged"},
"method-two":{"source":"example/method","ref":"v1"},
"stray":{"source":"elsewhere/wild","ref":"v2"},
"clankos-lint":{"source":"ClankaOperatingSystem/clankos","ref":"old"}}}
JSON
printf 'Local changes\n' > .agents/skills/method-one/SKILL.md
cp skills-lock.json "$work/lock"
cp .agents/skills/method-one/SKILL.md "$work/skill"
edit() {
    "$bin/clankos-run" installation-edit "$@" > "$work/out" 2> "$work/err"
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
check 'keep selected skills without installing' edit . remove example/method method-one --keep
check 'save selected keep and seed declared ownership only' python3 - <<'PY'
import json
s=json.load(open('.clankos/installation-state.json'))['managed']
assert {e['skill']:e['disposition'] for e in s}=={'method-one':'keep','method-two':None,'clankos-lint':None},s
assert all(e['node']=='.' for e in s)
assert all(not e['source'].startswith('https:') for e in s)
t=open('.clankos/config.yaml').read()
assert 'method-two' in t and 'method-one' not in t
PY
check 'edit preserves lock entries and hashes' cmp -s skills-lock.json "$work/lock"
check 'edit preserves locally modified skill files' cmp -s .agents/skills/method-one/SKILL.md "$work/skill"
check 'edit creates no refreshed wrappers' test ! -e .clankos/auto
check 'remove remaining source with default disposition' edit . remove example/method
check 'whole removal updates former identities too' python3 - <<'PY'
import json
s=json.load(open('.clankos/installation-state.json'))['managed']
assert all(e['disposition']=='remove' for e in s if e['source']=='example/method')
PY
check 'add source without installing' edit . add https://github.com/example/method.git v2 method-one
check 're-add retains pending choices until apply succeeds' python3 - <<'PY'
import json
s=json.load(open('.clankos/installation-state.json'))['managed']
assert next(e for e in s if e['skill']=='method-one')['disposition']=='remove'
PY
check 'adopt a wild-caught skill without installing' edit . adopt stray
check 'adoption saves ownership' python3 - <<'PY'
import json
s=json.load(open('.clankos/installation-state.json'))['managed']
assert next(e for e in s if e['skill']=='stray')['source']=='elsewhere/wild'
PY
cp .clankos/installation-state.json "$work/state"
cp .clankos/config.yaml "$work/config"
check 'repeat add succeeds' edit . add https://github.com/example/method.git v2 method-one
check 'repeat edit leaves state unchanged' cmp -s .clankos/installation-state.json "$work/state"
check 'repeat edit leaves configuration unchanged' cmp -s .clankos/config.yaml "$work/config"
printf '{broken' > skills-lock.json
check 'malformed lock is refused' status 1 edit . remove example/method
check 'bad lock leaves configuration unchanged' cmp -s .clankos/config.yaml "$work/config"
check 'bad lock leaves state unchanged' cmp -s .clankos/installation-state.json "$work/state"
mv skills-lock.json "$work/bad-lock"
ln -s "$work/lock" skills-lock.json
check 'lock symlink is refused' status 1 edit . remove example/method
rm skills-lock.json
cp "$work/lock" skills-lock.json
printf '{broken' > .clankos/installation-state.json
check 'malformed state is refused' status 1 edit . remove example/method
check 'bad state leaves configuration unchanged' cmp -s .clankos/config.yaml "$work/config"
cp "$work/state" .clankos/installation-state.json
check 'undeclared source is refused' status 1 edit . remove unknown/source
check 'invalid edit leaves state unchanged' cmp -s .clankos/installation-state.json "$work/state"
check 'unconfigured node is refused' status 1 edit other add https://github.com/example/method.git v1
check 'escaping node is refused' status 1 edit ../outside add https://github.com/example/method.git v1
mkdir vendor
git -C vendor init -q
check 'nested repository is refused' status 1 edit vendor add https://github.com/example/method.git v1
check 'missing arguments are usage' status 2 edit . add https://github.com/example/method.git
check 'invalid flag is usage' status 2 edit . add https://github.com/example/method.git v1 --keep
# A child configuration cannot be replaced, but root state can be saved.
cp "$work/original" area/.pos/config.yaml
cp "$work/lock" area/skills-lock.json
chmod a-w area/.pos
check 'failed configuration write reports failure' status 1 edit area remove example/method --keep
check 'failed write retains old configuration and pending intent' python3 - "$work/original" <<'PY'
import json,sys
assert open('area/.pos/config.yaml').read()==open(sys.argv[1]).read()
s=json.load(open('.clankos/installation-state.json'))['managed']
assert {e['skill']:e['disposition'] for e in s if e['node']=='area'}=={'method-one':'keep','method-two':'keep'}
PY
chmod u+w area/.pos
check 'retry completes the edit' edit area remove example/method --keep
check 'retry preserves other nodes and unrelated locks' cmp -s area/skills-lock.json "$work/lock"
python3 - <<'PYTEST'
import json
p='skills-lock.json'
s=json.load(open(p));del s['skills']['method-one']
with open(p,'w') as f: json.dump(s,f)
PYTEST
check 'record removal without a lock entry' edit . remove example/method method-one --keep
check 'keep remains specific to its identity' python3 - <<'PYTEST'
import json
s=json.load(open('.clankos/installation-state.json'))['managed']
assert next(e for e in s if e['node']=='.' and e['skill']=='method-one')['disposition']=='keep'
assert next(e for e in s if e['node']=='.' and e['skill']=='method-two')['disposition']=='remove'
assert next(e for e in s if e['skill']=='clankos-lint')['disposition'] is None
PYTEST
check 'planner reads the edited state' status 0 "$bin/clankos-run" installation-plan
# The state write must succeed before any child configuration changes.
printf 'pos: 2\n' > area/.pos/config.yaml
cp area/.pos/config.yaml "$work/child-config"
chmod a-w .clankos
check 'failed state write prevents configuration edit' status 1 edit area adopt stray
check 'failed state write leaves child configuration unchanged' cmp -s area/.pos/config.yaml "$work/child-config"
chmod u+w .clankos
# Editing a linked worktree does not require writable common Git metadata.
git add .clankos/config.yaml area/.pos/config.yaml
git -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm 'Create editor fixture'
git worktree add -qb linked "$work/linked"
mv .git/info "$work/git-info"
(cd "$work/linked" && edit . add https://github.com/example/another.git v1)
check 'linked worktree editing needs no writable metadata' test $? -eq 0
check 'linked worktree editing does not recreate exclusions' test ! -e .git/info
cd area || exit 1
check 'child working directory is refused' status 2 edit . add https://github.com/example/method.git v1
[ "$failures" -eq 0 ]
