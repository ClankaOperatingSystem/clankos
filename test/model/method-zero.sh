#!/usr/bin/env bash
# The image and method zero: what the image holds, and the image's own
# skills, which install puts in every node with no configuration naming
# them.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
. "$repo/test/lib/model.sh"
image_remote
. "$repo/test/lib/sources.sh"

check "The image holds Emacs, poslib, the commands and method zero." \
    docker run --rm --entrypoint sh "$CLANKOS_IMAGE" -c \
    'command -v emacs > /dev/null && test -f /usr/local/share/clankos/poslib/lisp/pos-node.elc \
        && test -x /usr/local/libexec/clankos/refresh \
        && test -f /usr/local/share/clankos/source/skills/capture/SKILL.md'
named() {
    local skill
    for skill in "$repo"/skills/*/; do
        case $(basename -- "$skill") in clankos-?*|capture|start-up|wrap-up) ;; *) return 1 ;; esac
    done
}
check "Method zero's skills are named clankos-NAME, apart from the slots it fills." named

garden
"$bin/clankos-run" install > ../out 2> ../err
commit=$(docker run --rm --entrypoint cat "$CLANKOS_IMAGE" /usr/local/share/clankos/source/commit)
at_commit() {
    local skill
    for skill in "$repo"/skills/*/; do
        grep -A3 "\"$(basename -- "$skill")\": {" skills-lock.json | grep -q "\"ref\": \"$commit\"" || return 1
    done
}
check "The image installs method zero at the commit the image was built from." at_commit
folders() {
    local skill name
    for skill in "$repo"/skills/*/; do
        name=$(basename -- "$skill")
        [ -d ".agents/skills/$name" ] && [ ! -L ".agents/skills/$name" ] \
            && cmp -s ".agents/skills/$name/SKILL.md" "$skill/SKILL.md" || return 1
    done
}
check "Method zero's skills are installed in .agents/skills/ as folders." folders
check "No configuration names method zero's skills." \
    ert pos-lint/an-entry-of-the-images-skills-is-declared

origin slot v1 capture
configure "$(declared slot v1 skills-repository)"
"$bin/clankos-run" install > ../out 2> ../err
check "A declared source's skill of a slot's name is installed in place of method zero's." \
    grep -qx 'Do it, v1.' .agents/skills/capture/SKILL.md

[ "$failures" -eq 0 ]
