#!/usr/bin/env bash
# The image and method zero: what the image holds, and the image's own
# skills, which a garden declares as a source, at the image's commit.
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

METHOD_ZERO= garden
"$bin/clankos-run" installation-edit . method-zero > ../out 2> ../err
commit=$(docker run --rm --entrypoint cat "$CLANKOS_IMAGE" /usr/local/share/clankos/source/commit)
declares() {
    grep -qx '  - source: https://github.com/ClankaOperatingSystem/clankos.git' .clanka/config.yml \
        && grep -qx "    ref: $commit" .clanka/config.yml \
        && grep -qx '    skills: \[capture, start-up, wrap-up, clankos-bootstrap\]' .clanka/config.yml \
        && grep -qx '    kind: skills-repository' .clanka/config.yml
}
check "A garden declares method zero as a source: the image's repository, at the commit the image was built from." declares
check "By default it declares capture, start-up, wrap-up and clankos-bootstrap." declares
git add -A && git commit -qm 'Declare method zero'
"$bin/clankos-run" apply-v1 > ../out 2> ../err
folders() {
    local name
    for name in capture start-up wrap-up clankos-bootstrap; do
        [ -d ".agents/skills/$name" ] && [ ! -L ".agents/skills/$name" ] \
            && cmp -s ".agents/skills/$name/SKILL.md" "$repo/skills/$name/SKILL.md" || return 1
    done
    [ ! -e .agents/skills/clankos-lint ]
}
check "Method zero's declared skills are installed in .agents/skills/ as folders, and no others." folders
at_commit() {
    grep -A3 '"start-up": {' skills-lock.json | grep -q "\"ref\": \"$commit\""
}
check "They are installed at the commit the image was built from." at_commit
"$bin/clankos-run" installation-edit . method-zero clankos-lint > ../out 2> ../err \
    && "$bin/clankos-run" apply-v1 > ../out 2> ../err
check "Another of the image's skills is added to the declaration, and installed." \
    test -f .agents/skills/clankos-lint/SKILL.md
sed -i.bak "s/ref: $commit/ref: v0.0.1/" .clanka/config.yml && rm .clanka/config.yml.bak
check "Apply refuses method zero declared at a ref other than the image's commit." \
    status 1 "$bin/clankos-run" apply-v1
origin impostor v1 clankos-impostor
METHOD_ZERO=$(method_zero) configure "$(declared impostor v1 skills-repository)"
check "Only the image's repository may supply a skill named clankos-NAME." sh -c \
    "! '$bin/clankos-run' install > ../out 2> ../err && grep -q 'clankos-impostor: the name clankos is reserved' ../err"

[ "$failures" -eq 0 ]
