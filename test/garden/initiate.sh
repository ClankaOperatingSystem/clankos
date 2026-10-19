#!/usr/bin/env bash
# Bootstrap using only an external copy of the bootstrap skill.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
image_remote
export GH_TOKEN=unused
cp -R "$repo/skills/clankos-bootstrap" 'bootstrap bundle'
bootstrap="$work/bootstrap bundle/scripts/bootstrap"
mkdir garden && cd garden && git init -q
"$bootstrap" --image v0.0.5 --no-tree > ../out 2> ../err
check 'standalone bootstrap succeeds' test $? -eq 0
check 'bootstrap records a fixed release' grep -qx 'image: ghcr.io/clankaoperatingsystem/clankos:v0.0.5' .clanka/config.yml
check 'bootstrap creates no wrappers' test ! -e bin -a ! -e .clanka/auto
check 'bootstrap installs method zero' test -x .agents/skills/clankos-lint/scripts/clankos
check 'bootstrap records ownership' test -s .clanka/installation-state.json
check 'bootstrap leaves optional methods unselected' sh -c '! grep -q "^methodologies:" .clanka/config.yml'
check 'bootstrap stages nothing' test -z "$(git ls-files)"
check 'bootstrap commits nothing' test -z "$(git log --oneline 2>/dev/null)"
check 'intray has its file ID' grep -qxE ':ID: +[0-9a-f-]{36}' intray.org
check 'uncommitted archives are ignored' git check-ignore -q .clanka/archives/evidence
check 'ledger is not ignored' sh -c '! git check-ignore -q .clanka/archive-integrity/ledger/event'
check 'files belong to the invoking user' test "$(owner .clanka/config.yml)" = "$(id -u)"
check 'installed capture works' sh -c '.agents/skills/capture/scripts/clankos capture -- "First task" >/dev/null 2>&1 && grep -q "First task" intray.org'
printf '# My instructions\n\n' > ../before
cat AGENTS.md >> ../before
printf '\nAfter the block.\n' >> ../before
cp ../before AGENTS.md
git add -A && git -c user.name=Test -c user.email=test@example.org commit -qm 'Bootstrap garden'
"$bootstrap" --no-tree > ../out 2> ../err
check 'repeat bootstrap succeeds' test $? -eq 0
check 'repeat bootstrap preserves committed content' test -z "$(git status --porcelain)"
git clone -q . ../clone
(cd ../clone && .agents/skills/capture/scripts/clankos capture -- 'From clone' >/dev/null 2>&1)
check 'fresh clone uses its committed bundle' grep -q 'From clone' ../clone/intray.org
check 'fresh clone has no auto/bin' test ! -e ../clone/.clanka/auto
cd ..
mkdir project && cd project && git init -q
"$bin/initiate" --image v0.0.5 --project --archive remote --keeper https://keeper.example/a > ../out 2> ../err
check 'source bootstrap entry succeeds' test $? -eq 0
check 'project has no projects directory declaration' sh -c '! grep -q "^projects:" .clanka/config.yml'
check 'remote archive policy is retained' grep -qx '    url: https://keeper.example/a' .clanka/config.yml
cd ..
mkdir held && cd held && git init -q && mkdir .pos
printf 'pos: 2\nprojects: projects/\nimage: ghcr.io/clankaoperatingsystem/clankos:v0.0.5\n' > .pos/config.yaml
cp .pos/config.yaml ../config-before
"$bootstrap" --archive committed --no-tree > ../out 2> ../err
check 'existing configuration is preserved' cmp -s .pos/config.yaml ../config-before
check 'no second configuration is made' test ! -e .clanka
mkdir -p child/.pos
printf 'pos: 2\nprojects: projects/\n' > child/.pos/config.yaml
printf 'children:\n  - path: child\n' >> .pos/config.yaml
"$bootstrap" --no-tree > ../out 2> ../err
check 'local child is applied' test -s child/skills-lock.json
check 'child archive exclusions are maintained' git check-ignore -q child/.pos/archives/evidence
cd ..
mkdir bad && cd bad && git init -q
check 'floating release is refused before writes' status 2 "$bootstrap" --image latest
check 'refused release writes nothing' test ! -e .clanka
check 'mismatched image roles refuse bootstrap' status 1 env CLANKOS_SKILLS_IMAGE="$CLANKOS_IMAGE" "$bootstrap" --image v0.0.5
check 'pair refusal writes no configuration' test ! -e .clanka
check 'invalid archive is refused' status 2 "$bootstrap" --image v0.0.5 --archive wrong
check 'invalid archive writes no configuration' test ! -e .clanka
mkdir nested && cd nested
check 'bootstrap below root is refused' status 2 "$bootstrap" --image v0.0.5
[ "$failures" -eq 0 ]
