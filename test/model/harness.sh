#!/usr/bin/env bash
# The harness: the program the coding agent runs in, which offers the
# agent the skills in .agents/skills/.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
. "$repo/test/lib/model.sh"
image_remote
. "$repo/test/lib/sources.sh"

# A harness that reads a directory of its own is given a link there to
# each skill; one that reads .agents/skills/ needs nothing more.
origin hello v1 hello-greet
garden
configure "$(declared hello v1)" 'harnesses: [claude-code]'
"$bin/clankos-run" install > ../out 2> ../err
check "A harness offers the agent every skill in .agents/skills/." \
    test -L .claude/skills/hello-greet -a -L .claude/skills/capture -a -d .agents/skills/hello-greet
held_by "the harness" "A harness offers the agent every skill in .agents/skills/."

[ "$failures" -eq 0 ]
