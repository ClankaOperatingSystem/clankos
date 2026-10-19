#!/usr/bin/env bash
# Upgrade applies one repository without staging or committing.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
image_remote
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GH_TOKEN=unused
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.org
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.org
mkdir -p child/.clanka garden/.clanka
 git -C child init -q -b master
printf 'pos: 2\nprojects: projects/\n' > child/.clanka/config.yml
git -C child add . && git -C child commit -qm 'Add a responsibility'
cd garden && git init -q -b master
printf 'pos: 2\nprojects: projects/\nimage: ghcr.io/clankaoperatingsystem/clankos:v0.0.1\nchildren:\n  - path: child\n    remote: %s\n  - path: local\n' "$work/child" > .clanka/config.yml
git clone -q "$work/child" child
mkdir -p local/.clanka
printf 'pos: 2\nprojects: projects/\n' > local/.clanka/config.yml
"$bin/responsibility-tree" --no-clone >/dev/null 2>&1
commit=$(docker run --rm "$CLANKOS_IMAGE" cat /usr/local/share/clankos/source/commit)
older=0000000000000000000000000000000000000000
for dir in child local .; do
    (cd "$dir" && "$bin/clankos-run" install >/dev/null 2>&1 &&
      sed -i.bak "s/$commit/$older/" skills-lock.json && rm skills-lock.json.bak)
done
git -C child add -A && git -C child commit -qm 'Install skills'
git add -A && git commit -qm 'Install skills'
root_head=$(git rev-parse HEAD)
child_head=$(git -C child rev-parse HEAD)
child_lock=$(sha256 child/skills-lock.json)
printf 'Staged work.\n' > intray.org && git add intray.org
git diff --cached --binary > ../index-before
# Use a copy so the test does not execute a script that apply can replace.
cp -R .agents/skills/clankos-upgrade ../upgrade
upgrade=$work/upgrade/scripts/upgrade
"$upgrade" --image v0.0.5 > ../out 2> ../err
check 'upgrade succeeds' test $? -eq 0
check 'root image records the selected release' grep -qx 'image: ghcr.io/clankaoperatingsystem/clankos:v0.0.5' .clanka/config.yml
check 'root skills record the image commit' grep -q "$commit" skills-lock.json
check 'local configured node is applied' grep -q "$commit" local/skills-lock.json
check 'mounted repository lock is unchanged' test "$(sha256 child/skills-lock.json)" = "$child_lock"
check 'neither repository is committed' test "$(git rev-parse HEAD):$(git -C child rev-parse HEAD)" = "$root_head:$child_head"
git diff --cached --binary > ../index-after
check 'staged work is unchanged' cmp -s ../index-before ../index-after
check 'upgrade changes remain unstaged' sh -c '! git diff --quiet -- skills-lock.json .clanka/config.yml'
check 'ownership is saved' test -f .clanka/installation-state.json
git diff --binary > ../before
"$upgrade" --image v0.0.5 > ../out 2> ../err
check 'repeat upgrade succeeds' test $? -eq 0
git diff --binary > ../after
check 'repeat upgrade makes no further tracked changes' cmp -s ../before ../after
# A refused apply keeps the target configuration for correction and retry.
printf '\nLocal change.\n' >> .agents/skills/clankos-lint/SKILL.md
"$upgrade" --image v0.0.6 > ../out 2> ../err
check 'modified managed skill refuses apply' test $? -ne 0
check 'refusal retains target intent' grep -qx 'image: ghcr.io/clankaoperatingsystem/clankos:v0.0.6' .clanka/config.yml
git diff --cached --binary > ../index-after
check 'refusal preserves staged work' cmp -s ../index-before ../index-after
check 'floating release is refused' status 2 "$upgrade" --image latest
[ "$failures" -eq 0 ]
