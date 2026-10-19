#!/usr/bin/env bash
# Apply saved intent across local nodes, and recover after a skills CLI failure.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=Fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
export GH_TOKEN=unused
unset SSH_AUTH_SOCK
image_remote
printf '[url "file://%s/remotes/"]\n\tinsteadOf = https://git.example/\n' "$work" >> "$XDG_CONFIG_HOME/git/config"
origin() {
    local name=$1 tag=$2 dir=$work/sources/$1
    shift 2
    [ -d "$dir" ] || git init -qb master "$dir"
    for skill in "$@"; do
        mkdir -p "$dir/skills/$skill"
        printf -- '---\nname: %s\ndescription: Fixture skill.\n---\n%s\n' "$skill" "$tag" > "$dir/skills/$skill/SKILL.md"
    done
    git -C "$dir" add -A && git -C "$dir" commit -qm "$tag" && git -C "$dir" tag "$tag"
    [ ! -d "$work/remotes/$name.git" ] || rm -rf "$work/remotes/$name.git"
    git clone -q --bare "$dir" "$work/remotes/$name.git"
}
origin hello v1 hello-greet hello-part
origin hello v2 hello-greet hello-part
origin other v1 other-one
mkdir -p garden/.clankos garden/area/.pos garden/vendor/.pos
cd garden || exit 1
git init -qb master
git -C vendor init -q
printf 'malformed YAML [' > vendor/.pos/config.yaml
cat > .clankos/config.yaml <<'YAML'
pos: 2
children:
  - path: area
  - path: vendor
methodologies:
  - source: https://git.example/hello.git
    ref: v1
    skills: [hello-greet, hello-part]
YAML
cat > area/.pos/config.yaml <<'YAML'
pos: 2
methodologies:
  - source: https://git.example/hello.git
    ref: v1
    skills: [hello-greet]
YAML
git add .clankos area/.pos && git commit -qm 'Create apply fixture'
git write-tree > "$work/index"
apply() {
    "$bin/clankos-run" apply-v1 > "$work/out" 2> "$work/err"
    local result=$?
    if [ "$result" -ne 0 ]; then cat "$work/out" "$work/err"; fi
    return "$result"
}
edit() { "$bin/clankos-run" installation-edit "$@" > "$work/out" 2> "$work/err"; }
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
check 'apply installs local nodes without entering a nested repository' apply
check 'root source is installed' grep -qx v1 .agents/skills/hello-part/SKILL.md
check 'child source is installed' grep -qx v1 area/.agents/skills/hello-greet/SKILL.md
check 'method zero is installed at the root' test -f .agents/skills/clankos-lint/SKILL.md
check 'nested repository remains untouched' test ! -e vendor/.agents
check 'apply does not refresh wrappers' test ! -e .clankos/auto
check 'apply does not stage files' test "$(git write-tree)" = "$(cat "$work/index")"
git add .clankos area/.pos .agents skills-lock.json area/.agents area/skills-lock.json
git commit -qm 'Keep installed fixture'
check 'unchanged apply succeeds' apply
check 'unchanged apply changes no managed files' test -z "$(git status --porcelain --untracked-files=no)"
check 'save selected keep' edit . remove https://git.example/hello.git hello-greet --keep
check 'apply selected keep' apply
check 'kept skill remains installed' test -f .agents/skills/hello-greet/SKILL.md
check 'keep releases ownership but retains other identities' python3 - <<'PY'
import json
s=json.load(open('.clankos/installation-state.json'))['managed']
assert not any(e['node']=='.' and e['skill']=='hello-greet' for e in s)
assert any(e['node']=='.' and e['skill']=='hello-part' for e in s)
PY
printf 'Local changes to a kept skill.\n' >> .agents/skills/hello-greet/SKILL.md
cp .agents/skills/hello-greet/SKILL.md "$work/kept"
check 'later apply preserves released skill despite its declared source' apply
check 'kept local edits survive' cmp -s .agents/skills/hello-greet/SKILL.md "$work/kept"
# Refuse every node before installing the newly desired root source.
check 'edit an unrelated source without reclaiming kept skills' edit . add https://git.example/other.git v1
printf 'Local change\n' >> area/.agents/skills/hello-greet/SKILL.md
cp .clankos/installation-state.json "$work/state"
check 'local modification in a later node refuses the whole preflight' status 1 apply
check 'earlier node is not installed after a preflight refusal' test ! -e .agents/skills/other-one
check 'preflight failure leaves ownership unchanged' cmp -s .clankos/installation-state.json "$work/state"
git show HEAD:area/.agents/skills/hello-greet/SKILL.md > area/.agents/skills/hello-greet/SKILL.md
check 'retry after restoring local edits succeeds' apply
check 'unrelated edit did not reclaim the kept skill' cmp -s .agents/skills/hello-greet/SKILL.md "$work/kept"
check 'update selected source revision' edit . add https://git.example/hello.git v2 hello-part
check 'apply updates desired files' apply
check 'selected skill reaches v2' grep -qx v2 .agents/skills/hello-part/SKILL.md
check 'kept skill stays at its old bytes' cmp -s .agents/skills/hello-greet/SKILL.md "$work/kept"
# Fail after the real CLI has installed the child, leaving partial progress.
check 'save keep before an interrupted apply' edit . remove https://git.example/hello.git hello-part --keep
check 'prepare child update' edit area add https://git.example/hello.git v2 hello-greet
export REAL_DOCKER=$(command -v docker) APPLY_FIXTURE_BIN="$work/shim"
mkdir "$work/shim" "$work/docker-bin"
cat > "$work/shim/skills" <<'SHIM'
#!/bin/sh
/usr/local/bin/skills "$@"
result=$?
case "$PWD:$1" in
    */garden/area:add)
        # Simulate a stop after copying files but before writing the lock.
        rm -f skills-lock.json
        echo 'fixture: interrupted before recording the lock' >&2
        exit 37 ;;
esac
exit "$result"
SHIM
cat > "$work/docker-bin/docker" <<'DOCKER'
#!/usr/bin/env bash
[ "$1" = run ] || exec "$REAL_DOCKER" "$@"
shift
exec "$REAL_DOCKER" run -v "$APPLY_FIXTURE_BIN:/apply-fixture-bin:ro" \
    -e PATH=/apply-fixture-bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin "$@"
DOCKER
chmod +x "$work/shim/skills" "$work/docker-bin/docker"
check 'CLI failure reports incomplete apply' status 3 env PATH="$work/docker-bin:$PATH" "$bin/clankos-run" apply-v1
check 'failure occurred after installing the child' grep -qx v2 area/.agents/skills/hello-greet/SKILL.md
check 'interruption left no lock entry' test ! -e area/skills-lock.json
check 'failed apply retains the pending keep choice' python3 - <<'PY'
import json
s=json.load(open('.clankos/installation-state.json'))['managed']
assert next(e for e in s if e['node']=='.' and e['skill']=='hello-part')['disposition']=='keep'
assert 'v2' in open('area/.pos/config.yaml').read()
PY
check 'retry completes from the installed state' apply
check 'successful retry releases the kept identity' python3 - <<'PY'
import json
assert not any(e['node']=='.' and e['skill']=='hello-part' for e in json.load(open('.clankos/installation-state.json'))['managed'])
PY
# An old identity cannot remove a same-name skill now owned by another source.
python3 - <<'PY'
import json
p='skills-lock.json';s=json.load(open(p));e=s['skills']['hello-greet']
e['source']='elsewhere/replacement';e['sourceUrl']='https://github.com/elsewhere/replacement.git'
with open(p,'w') as f: json.dump(s,f)
p='.clankos/installation-state.json';s=json.load(open(p))
s['managed'].append({'node':'.','source':'https://git.example/hello.git','skill':'hello-greet','disposition':'remove'})
with open(p,'w') as f: json.dump(s,f)
PY
check 'stale source ownership does not remove a replacement' apply
check 'replacement files remain unchanged' cmp -s .agents/skills/hello-greet/SKILL.md "$work/kept"
cp skills-lock.json "$work/lock"
printf '{broken' > skills-lock.json
check 'malformed lock refuses apply' status 1 apply
cp "$work/lock" skills-lock.json
# Refuse paths that would let the CLI alter another directory or repository.
mkdir -p "$work/external" .agents/skills/other-one/.git
printf 'Untouched\n' > "$work/external/marker"
check 'nested repository inside an installed skill is refused' status 1 apply
mv .agents/skills/other-one/.git "$work/skill-git"
ln -s "$work/external" .claude
check 'a harness path through a symlink is refused' status 1 apply
check 'symlink target remains untouched' grep -qx Untouched "$work/external/marker"
rm .claude
# Remove a node from discovery; its history still schedules cleanup.
python3 - <<'PY'
p='.clankos/config.yaml';s=open(p).read().replace('  - path: area\n','')
with open(p,'w') as f: f.write(s)
import json
p='.clankos/installation-state.json';s=json.load(open(p))
s['managed'].append({'node':'gone','source':'https://git.example/hello.git','skill':'hello-greet','disposition':'remove'})
with open(p,'w') as f: json.dump(s,f)
PY
git -C area init -q
check 'cleanup refuses a node that became a separate repository' status 1 apply
check 'refused cleanup preserves the child skill' test -f area/.agents/skills/hello-greet/SKILL.md
mv area/.git "$work/child-git"
check 'apply cleans a formerly configured node' apply
check 'cleanup removes managed files' test ! -e area/.agents/skills/hello-greet
check 'cleanup clears completed ownership' python3 - <<'PY'
import json
assert all(e['node'] not in ('area','gone') for e in json.load(open('.clankos/installation-state.json'))['managed'])
PY
git worktree add -qb linked "$work/linked"
# Keep source fixtures inside this worktree's mount. The main repository's
# Git metadata must be reached through the launcher's separate mounts.
cp -R "$work/remotes" "$work/linked/remotes"
mkdir -p "$work/linked/config/git"
printf '[url "file://%s/remotes/"]\n\tinsteadOf = https://git.example/\n[url "file://%s/remotes/clankos.git"]\n\tinsteadOf = https://github.com/ClankaOperatingSystem/clankos.git\n' \
    "$work/linked" "$work/linked" > "$work/linked/config/git/config"
(cd "$work/linked" && unset CLANKOS_WORKSPACE && export XDG_CONFIG_HOME="$work/linked/config" && apply)
check 'apply works with Git metadata outside the worktree mount' test $? -eq 0
cd area || exit 1
check 'apply from a child refuses to widen scope' status 2 "$bin/clankos-run" apply-v1
[ "$failures" -eq 0 ]
