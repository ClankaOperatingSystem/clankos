#!/usr/bin/env bash
# Bootstrap a garden using only an external copy of the bootstrap
# skill, opt in to the rest of method zero's skills, and run each skill's
# script; bootstrap again, and in a fresh clone; and bootstrap a
# repository that has a configuration of its own.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
image_remote
export GH_TOKEN=unused
# A separate methodology has two revisions, served without the network.
mkdir -p "$work/hello/skills/hello-greet"
git -C "$work/hello" init -q
for version in v1 v2; do
    printf '%s\n' '---' 'name: hello-greet' 'description: Greet.' '---' "$version" > "$work/hello/skills/hello-greet/SKILL.md"
    git -C "$work/hello" add .
    git -C "$work/hello" -c user.name=Test -c user.email=test@example.org commit -qm "Write $version"
    git -C "$work/hello" tag "$version"
done
git clone -q --bare "$work/hello" "$work/remotes/hello.git"
git config -f "$XDG_CONFIG_HOME/git/config" url."file://$work/remotes/hello.git".insteadOf https://example.test/hello.git
cp -R "$repo/skills/clankos-bootstrap" 'bootstrap bundle'
bootstrap="$work/bootstrap bundle/scripts/bootstrap"
mkdir garden && cd garden && git init -q
"$bootstrap" --image v0.0.5 --no-tree > ../out 2> ../err
check 'standalone bootstrap succeeds' test $? -eq 0
check 'bootstrap writes no pos key' sh -c '! grep -q "^pos:" .clanka/config.yml'
check 'bootstrap records a fixed release' grep -qx 'image: ghcr.io/clankaoperatingsystem/clankos:v0.0.5' .clanka/config.yml
check 'bootstrap creates no wrappers' test ! -e bin -a ! -e .clanka/auto
check 'bootstrap installs method zero' test -x .agents/skills/clankos-bootstrap/scripts/clankos
check 'and only its default skills' \
    test "$(ls .agents/skills | tr '\n' ' ')" = 'capture clankos-bootstrap start-up wrap-up '
check 'bootstrap records ownership' test -s .clanka/installation-state.json
check 'bootstrap declares method zero as a source' \
    grep -qx '  - source: https://github.com/ClankaOperatingSystem/clankos.git' .clanka/config.yml
check 'bootstrap leaves optional methods unselected' test "$(grep -c '^  - source:' .clanka/config.yml)" -eq 1
check 'bootstrap stages nothing' test -z "$(git ls-files)"
check 'bootstrap commits nothing' test -z "$(git log --oneline 2>/dev/null)"
check 'intray has its file ID' grep -qxE ':ID: +[0-9a-f-]{36}' intray.org
check 'uncommitted archives are ignored' git check-ignore -q .clanka/archives/evidence
check 'ledger is not ignored' sh -c '! git check-ignore -q .clanka/archive-integrity/ledger/event'
check 'files belong to the invoking user' test "$(owner .clanka/config.yml)" = "$(id -u)"
check 'installed capture works' sh -c '.agents/skills/capture/scripts/clankos capture -- "First task" >/dev/null 2>&1 && grep -q "First task" intray.org'
check "AGENTS.md says where the skills are" grep -q '.agents/skills/' AGENTS.md
"$bin/responsibility-tree" --no-clone > ../out 2>&1
check "responsibility-tree finds no skill of method zero wild-caught" sh -c "! grep -q 'wild-caught' ../out"
cp skills-lock.json ../lock
python3 - <<'PY'
import json
lock = json.load(open('skills-lock.json'))
lock['skills']['stray'] = {'source': 'example/stray', 'ref': 'v1',
                           'sourceType': 'github', 'skillPath': 'skills/stray/SKILL.md'}
json.dump(lock, open('skills-lock.json', 'w'), indent=2)
PY
settle
"$bin/responsibility-tree" --no-clone > ../out 2>&1
check "and still reports a skill from an undeclared source" \
    grep -qx 'finding   wild-caught skills-lock.json (stray: from example/stray, which is not declared)' ../out
check "and it alone" test "$(grep -c 'wild-caught' ../out)" -eq 1
cp ../lock skills-lock.json
settle

# Opt in to the rest of method zero's skills.
# shellcheck disable=SC2046
"$bin/clankos-run" installation-edit . method-zero $(ls "$repo/skills") > ../out 2>&1
"$bin/clankos-run" apply-v1 > ../out 2>&1
check "and installs the rest once they are declared" test $? -eq 0
for skill in "$repo"/skills/*/; do
    name=$(basename -- "$skill")
    check "$name is installed as the image has it" cmp -s ".agents/skills/$name/SKILL.md" "$skill/SKILL.md"
done
check "the skills and skills-lock.json are there to commit, and auto/ is not" \
    sh -c 'git status --porcelain | grep -qx "?? .agents/" && git status --porcelain | grep -qx "?? skills-lock.json" && ! git status --porcelain --untracked-files=all | grep -q "\.clanka/auto"'
"$bin/clankos-run" refresh > ../out 2> ../err
check "refresh finds them as installed" test $? -eq 0 -a ! -s ../err
check "AGENTS.md says where the skills are" grep -q '.agents/skills/' AGENTS.md

.agents/skills/capture/scripts/clankos capture -- 'From the root' > ../out 2>&1
check "a skill's script runs a command where the session is" grep -q 'From the root' intray.org
check "and the capture slot's command prints where the item is" grep -q '^.*/intray.org:[0-9]*: TODO From the root$' ../out
"$bin/responsibility-tree" --no-clone --responsibility health > ../out 2>&1
(cd health && ../.agents/skills/capture/scripts/clankos capture -- 'From a responsibility' > ../../out 2>&1)
check "run in a responsibility, it works on that responsibility" \
    sh -c "grep -q 'From a responsibility' health/intray.org && ! grep -q 'From a responsibility' intray.org"
check "a command that is not one is refused" status 127 .agents/skills/capture/scripts/clankos no-such-command
check "the start-up skill's script prints the prompts" \
    sh -c ".agents/skills/start-up/scripts/clankos start-up 2>/dev/null | grep -q 'START-UP PROMPTS'"
check "and the handover view, empty" \
    sh -c ".agents/skills/start-up/scripts/clankos start-up 2>/dev/null | grep -A1 '^Latest handover\$' | grep -q '^  (none)\$'"
printf 'What happened.\n' | .agents/skills/wrap-up/scripts/clankos wrap-up -- 'The first session' > ../out 2>&1
check "the wrap-up skill's script keeps a handover and prints its citation" \
    grep -q "^ipfs://[a-z0-9]*: The first session, $(date +%Y-%m-%d)\$" ../out
check "which the start-up skill's script then names" \
    sh -c ".agents/skills/start-up/scripts/clankos start-up --view handover 2>/dev/null | grep -q '^  journal  *$(date +%Y-%m-%d) The first session ipfs://'"
echo "A sealed sentence." | .agents/skills/clankos-seal/scripts/clankos archive-integrity write-new .clanka/archives/2026-01-01-sentence.txt --apply > ../out 2>&1
check "the search skill's script finds a sealed line and cites it" \
    sh -c ".agents/skills/clankos-search-evidence/scripts/clankos archive-integrity search . sealed | grep -q '^ipfs://[a-z0-9]*:1:A sealed sentence\.$'"
check "the search skill says never to grep an archive" grep -q 'never with grep' "$repo/skills/clankos-search-evidence/SKILL.md"

printf '# My instructions\n\n' > ../before
cat AGENTS.md >> ../before
printf '\nAfter the block.\n' >> ../before
cp ../before AGENTS.md
git add -A && git -c user.name=Test -c user.email=test@example.org commit -qm 'Bootstrap garden'
"$bootstrap" > ../out 2> ../err
check 'repeat bootstrap succeeds' test $? -eq 0
check 'repeat bootstrap preserves committed content' test -z "$(git status --porcelain)"
git clone -q . ../clone
(cd ../clone && .agents/skills/capture/scripts/clankos capture -- 'From clone' >/dev/null 2>&1)
check 'fresh clone uses its committed bundle' grep -q 'From clone' ../clone/intray.org
check 'fresh clone has no auto/bin' test ! -e ../clone/.clanka/auto
cd ..
mkdir held && cd held && git init -q && mkdir .pos
printf 'pos: 2\nprojects: projects/\nimage: ghcr.io/clankaoperatingsystem/clankos:v0.0.5\n' > .pos/config.yaml
cp .pos/config.yaml ../config-before
"$bootstrap" --archive committed --no-tree > ../out 2> ../err
check 'existing configuration is preserved' sh -c "! diff ../config-before .pos/config.yaml | grep -q '^<'"
check 'and method zero is declared in it' grep -q 'ClankaOperatingSystem/clankos.git' .pos/config.yaml
check 'no second configuration is made' test ! -e .clanka
mkdir -p child/.pos
printf 'pos: 2\nprojects: projects/\nmethodologies:\n  - source: https://example.test/hello.git\n    ref: v1\n    skills: [hello-greet]\n' > child/.pos/config.yaml
printf 'children:\n  - path: child\n' >> .pos/config.yaml
"$bootstrap" --no-tree > ../out 2> ../err
check 'local child is applied' grep -qx v1 child/.agents/skills/hello-greet/SKILL.md
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
