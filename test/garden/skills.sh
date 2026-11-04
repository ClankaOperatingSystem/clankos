#!/usr/bin/env bash
# The skills the image installs, and that the script each carries runs
# the commands from wherever a session is started.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
image_remote

mkdir garden && cd garden && git init -q .
"$bin/initiate" --no-tree < /dev/null > ../out 2>&1
check "initiate installs method zero's default skills alone" \
    test "$(ls .agents/skills | tr '\n' ' ')" = 'capture clankos-bootstrap start-up wrap-up '
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
"$bin/responsibility-tree" --responsibility health > ../out 2>&1
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

[ "$failures" -eq 0 ]
