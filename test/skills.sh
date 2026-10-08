#!/usr/bin/env bash
# The skills the image installs: what each is, and that the script each
# carries runs the commands from wherever a session is started.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

for skill in "$repo"/skills/*/; do
    name=$(basename -- "$skill")
    check "$name is named clankos-NAME" sh -c "case $name in clankos-?*) ;; *) exit 1 ;; esac"
    check "$name says its name, which is its directory's" \
        test "$(sed -n '2p' "$skill/SKILL.md")" = "name: $name"
    check "$name has a description on one line, with no colon a YAML reader would trip on" \
        sh -c "sed -n '3p' '$skill/SKILL.md' | grep -q '^description: [^:]*\(:[^ ][^:]*\)*\$'"
    check "$name carries the script that runs the commands" test -x "$skill/scripts/clankos"
done

mkdir garden && cd garden && git init -q .
"$bin/initiate" --no-tree < /dev/null > ../out 2>&1
check "a new garden has each skill as a link to what is installed" \
    test "$(readlink .agents/skills/clankos-capture)" = ../../.clanka/auto/skills/clankos-capture
for skill in "$repo"/skills/*/; do
    name=$(basename -- "$skill")
    check "$name is installed as the image has it" cmp -s ".agents/skills/$name/SKILL.md" "$skill/SKILL.md"
done
check "an agent that reads .claude/skills finds them too" \
    test "$(readlink .claude/skills)" = ../.agents/skills -a -f .claude/skills/clankos-seal/SKILL.md
check "Git keeps none of it" \
    sh -c '! git status --porcelain --untracked-files=all | grep -q "\.agents\|\.claude\|\.clanka/auto"'
check "AGENTS.md says where the skills are" grep -q 'clankos-NAME' AGENTS.md

.agents/skills/clankos-capture/scripts/clankos pos-capture -- 'From the root' > ../out 2>&1
check "a skill's script runs a command where the session is" grep -q 'From the root' intray.org
"$bin/responsibility-tree" --responsibility health > ../out 2>&1
(cd health && ../.agents/skills/clankos-capture/scripts/clankos pos-capture -- 'From a responsibility' > ../../out 2>&1)
check "run in a responsibility, it works on that responsibility" \
    sh -c "grep -q 'From a responsibility' health/intray.org && ! grep -q 'From a responsibility' intray.org"
check "a command that is not one is refused" status 127 .agents/skills/clankos-capture/scripts/clankos no-such-command
check "the start-up skill's script prints the prompts" \
    sh -c ".agents/skills/clankos-start-up/scripts/clankos startup-prompt 2>/dev/null | grep -q 'START-UP PROMPTS'"

mkdir -p .agents/skills/mine && printf '%s\n' '---' 'name: mine' 'description: Mine.' '---' > .agents/skills/mine/SKILL.md
"$bin/clankos-run" refresh > ../out 2> ../err
check "a skill of the garden's own is left alone" test -f .agents/skills/mine/SKILL.md -a ! -L .agents/skills/mine

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
check "the project's .claude/skills finds it too" test -f projects/p/.claude/skills/hello-greet/SKILL.md
check "nothing of the methodology is linked at the root" test ! -e .agents/skills/hello-greet
check "Git keeps none of that either" \
    sh -c '! git status --porcelain --untracked-files=all | grep -q "projects/p/\.agents\|projects/p/\.claude\|projects/p/bin"'
mkdir -p projects/p/methodologies/hello/skills/greet && printf '%s\n' '---' 'name: greet' 'description: Bad.' '---' > projects/p/methodologies/hello/skills/greet/SKILL.md
"$bin/clankos-run" refresh > ../out 2> ../err
check "a skill named without the methodology's prefix is reported" grep -q 'methodology-refused' ../err

[ "$failures" -eq 0 ]
