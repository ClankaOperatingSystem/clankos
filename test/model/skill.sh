#!/usr/bin/env bash
# A skill: a folder holding SKILL.md, in agentskills.io's format, which
# the skills CLI copies and ClankOS knows by its name alone.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
. "$repo/test/lib/model.sh"
image_remote
. "$repo/test/lib/sources.sh"

# A source whose skills/ holds a folder with no SKILL.md.
origin hello v1 hello-greet
mkdir -p sources/hello/skills/hello-notes && printf 'Notes.\n' > sources/hello/skills/hello-notes/README
publish hello v2
garden
configure "$(declared hello v2)"
"$bin/clankos-run" install > ../out 2> ../err
check "A skill is a folder that holds SKILL.md." \
    test -f .agents/skills/hello-greet/SKILL.md -a ! -e .agents/skills/hello-notes

held_by "agentskills.io's format" "A skill's references/ holds what the agent reads."
held_by "agentskills.io's format" "A skill's scripts/ holds what the agent runs."
held_by "the skills CLI" "A skill folder follows agentskills.io's format."
held_by "nothing" "ClankOS reads only the skill folder's name."

[ "$failures" -eq 0 ]
