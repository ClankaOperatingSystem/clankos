#!/usr/bin/env bash
# The slots: the skills a repository may fill with its own, which
# install then leaves to it.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
. "$repo/test/lib/model.sh"
image_remote
. "$repo/test/lib/sources.sh"

slots() {
    [ "$(cd "$repo/skills" && ls -d -- */ | grep -v '^clankos-' | tr '\n' ' ')" \
        = 'capture/ start-up/ wrap-up/ ' ]
}
check "A slot is a skill a repository may fill with a skill of its own: capture, start-up or wrap-up." slots
held_by "poslib's doc/pos-slots.txt" "poslib's doc/pos-slots.txt gives each slot's signature."

# A garden that fills the wrap-up slot with a skill of its own.
origin slot v1 wrap-up
garden
mkdir -p .agents/skills/wrap-up && printf '%s\n' '---' 'name: wrap-up' 'description: Ours.' '---' > .agents/skills/wrap-up/SKILL.md
git add .agents && git commit -qm 'Fill the wrap-up slot'
"$bin/clankos-run" install > ../out 2> ../err
"$bin/clankos-run" refresh > ../out 2> ../err
refresh=$?
left() {
    [ "$refresh" -eq 0 ] && [ ! -s ../err ] \
        && [ "$(sed -n '3p' .agents/skills/wrap-up/SKILL.md)" = 'description: Ours.' ] \
        && ! grep -q '"wrap-up"' skills-lock.json \
        && [ -f .agents/skills/capture/SKILL.md ] \
        && configure "$(declared slot v1 skills-repository)" \
        && ! "$bin/clankos-run" install > ../out 2> ../err \
        && grep -q 'wrap-up: the repository fills this slot itself' ../err
}
check "Install leaves a slot that the garden fills alone." left

[ "$failures" -eq 0 ]
