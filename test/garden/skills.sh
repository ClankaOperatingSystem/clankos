#!/usr/bin/env bash
# The skills the image installs: what each is, and that the script each
# carries runs the commands from wherever a session is started.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
image_remote

for skill in "$repo"/skills/*/; do
    name=$(basename -- "$skill")
    check "$name is named clankos-NAME, or a slot's name" \
        sh -c "case $name in clankos-?*|capture|start-up|wrap-up) ;; *) exit 1 ;; esac"
    check "$name says its name, which is its directory's" \
        test "$(sed -n '2p' "$skill/SKILL.md")" = "name: $name"
    check "$name has a description on one line, with no colon a YAML reader would trip on" \
        sh -c "sed -n '3p' '$skill/SKILL.md' | grep -q '^description: [^:]*\(:[^ ][^:]*\)*\$'"
    check "$name carries the script that runs the commands" test -x "$skill/scripts/clankos"
done

mkdir garden && cd garden && git init -q .
"$bin/initiate" --no-tree < /dev/null > ../out 2>&1
check "a new garden has each skill installed, as a folder" \
    test -d .agents/skills/capture -a ! -L .agents/skills/capture
for skill in "$repo"/skills/*/; do
    name=$(basename -- "$skill")
    check "$name is installed as the image has it" cmp -s ".agents/skills/$name/SKILL.md" "$skill/SKILL.md"
done
commit=$(docker run --rm "$CLANKOS_IMAGE" cat /usr/local/share/clankos/source/commit)
check "skills-lock.json records them at the image's commit" grep -q "\"ref\": \"$commit\"" skills-lock.json
check "the skills and skills-lock.json are there to commit, and auto/ is not" \
    sh -c 'git status --porcelain | grep -qx "?? .agents/" && git status --porcelain | grep -qx "?? skills-lock.json" && ! git status --porcelain --untracked-files=all | grep -q "\.clanka/auto"'
"$bin/clankos-run" refresh > ../out 2> ../err
check "refresh finds them as installed" test $? -eq 0 -a ! -s ../err
check "AGENTS.md says where the skills are" grep -q 'clankos-NAME' AGENTS.md

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

mkdir -p .agents/skills/mine && printf '%s\n' '---' 'name: mine' 'description: Mine.' '---' > .agents/skills/mine/SKILL.md
"$bin/clankos-run" refresh > ../out 2> ../err
check "a skill of the garden's own is left alone" test -f .agents/skills/mine/SKILL.md -a ! -L .agents/skills/mine

printf 'Edited.\n' >> .agents/skills/clankos-seal/SKILL.md
"$bin/clankos-run" refresh > ../out 2> ../err
check "a skill edited where it is installed exits 1" test $? -eq 1
check "and is named on stderr" \
    grep -qx 'clankos: lock-differs skills-lock.json (clankos-seal: changed since it was installed)' ../err
cp "$repo/skills/clankos-seal/SKILL.md" .agents/skills/clankos-seal/SKILL.md

# A garden that fills the wrap-up slot with a skill of its own: the
# image's is not installed there, and nothing is reported.
mkdir ../filled && cd ../filled && git init -q .
mkdir -p .agents/skills/wrap-up && printf '%s\n' '---' 'name: wrap-up' 'description: Ours.' '---' > .agents/skills/wrap-up/SKILL.md
git add .agents && git -c user.name=Test -c user.email=test@example.org commit -qm 'Fill the wrap-up slot'
"$bin/initiate" --no-tree < /dev/null > ../out 2>&1
"$bin/clankos-run" refresh > ../out 2> ../err
check "a skill of the garden's own under a slot's name is its filling: refresh exits 0" test $? -eq 0
check "and reports nothing" test ! -s ../err
check "and the skill stays the garden's" test "$(sed -n '3p' .agents/skills/wrap-up/SKILL.md)" = 'description: Ours.'
check "and has no lock entry" sh -c '! grep -q "\"wrap-up\"" skills-lock.json'
check "while the image's other skills are installed" test -f .agents/skills/capture/SKILL.md
cd ../garden

# A project that is a directory of the garden uses a methodology, hello,
# whose skill and command are linked where they lie, in the project.
mkdir -p projects/p/.clanka projects/p/methodologies/hello/skills/hello-greet projects/p/methodologies/hello/bin
grep -q '^children:' .clanka/config.yml || printf 'children:\n' >> .clanka/config.yml
printf '  - path: projects/p\n' >> .clanka/config.yml
printf 'pos: 2\nmethodologies: methodologies\nbin: bin\nchildren:\n  - path: methodologies/hello\n' > projects/p/.clanka/config.yml
printf '%s\n' '---' 'name: hello-greet' 'description: Greet.' '---' > projects/p/methodologies/hello/skills/hello-greet/SKILL.md
printf '#!/bin/sh\necho Hello.\n' > projects/p/methodologies/hello/bin/hello-greet && chmod +x projects/p/methodologies/hello/bin/hello-greet
"$bin/clankos-run" refresh > ../out 2> ../err
check "a methodology's skill is linked in the project, where it lies" \
    test "$(readlink projects/p/.agents/skills/hello-greet)" = ../../methodologies/hello/skills/hello-greet
check "and its command, where the project says bin" \
    test "$(readlink projects/p/bin/hello-greet)" = ../methodologies/hello/bin/hello-greet
check "nothing of the methodology is linked at the root" test ! -e .agents/skills/hello-greet
check "Git keeps none of that either" \
    sh -c '! git status --porcelain --untracked-files=all | grep -q "projects/p/\.agents\|projects/p/bin"'
mkdir -p projects/p/methodologies/hello/skills/greet && printf '%s\n' '---' 'name: greet' 'description: Bad.' '---' > projects/p/methodologies/hello/skills/greet/SKILL.md
"$bin/clankos-run" refresh > ../out 2> ../err
check "a skill named without the methodology's prefix is reported" grep -q 'methodology-refused' ../err

# A responsibility may have methodologies, and its skills are linked in it.
mkdir -p work/.clanka work/methodologies/trade/skills/trade-greet
printf '  - path: work\n' >> .clanka/config.yml
printf 'pos: 2\nprojects: projects/\nmethodologies: methodologies\nchildren:\n  - path: methodologies/trade\n' > work/.clanka/config.yml
printf '%s\n' '---' 'name: trade-greet' 'description: Greet.' '---' > work/methodologies/trade/skills/trade-greet/SKILL.md
"$bin/clankos-run" refresh > ../out 2> ../err
check "a responsibility's methodology is linked in the responsibility" \
    test "$(readlink work/.agents/skills/trade-greet)" = ../../methodologies/trade/skills/trade-greet

[ "$failures" -eq 0 ]
