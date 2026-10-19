#!/usr/bin/env bash
# A source: a Git repository, declared at a ref, of one kind. Install
# reads each through poslib's configuration reader, and refuses what
# the reader refuses or what the fetched repository breaks.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
. "$repo/test/lib/model.sh"
image_remote
. "$repo/test/lib/sources.sh"

origin hello v1 hello-greet
git -C sources/hello branch -q stable \
    && rm -rf remotes/hello.git && git clone -q --bare sources/hello remotes/hello.git
origin loose v1 loose-greet greet
origin reserved v1 clankos-seal
garden
configure "$(declared hello v1)"
git add . && git commit -qm 'Declare hello'

# refused PATTERN: whether install exits 1, says PATTERN on stderr and
# changes nothing but the configuration.
refused() {
    "$bin/clankos-run" install > ../out 2> ../err
    local status=$?
    [ $status -eq 1 ] && grep -q "$1" ../err \
        && [ "$(git status --porcelain)" = ' M .clanka/config.yml' ]
}
at_tag_or_commit() {
    fixture refused-ref-a-flag \
        && configure "$(declared hello stable)" && refused 'stable is a branch'
}
prefixed() {
    fixture refused-skill-without-prefix \
        && configure "$(declared loose v1)" \
        && refused 'greet: a skill of https://git.example/loose.git not named loose-NAME'
}
not_reserved() {
    fixture refused-source-named-clankos && fixture refused-methodology-named-clankos \
        && configure "$(declared reserved v1 skills-repository)" && refused clankos-seal
}

check "A source is declared by a Git URL." fixture refused-source-not-a-url
check "A source is declared at a tag or at a full commit." \
    at_tag_or_commit
check "A source is of one kind: methodology or skills-repository." fixture refused-kind-unknown
check "A methodology's skills are named with the repository's name and a hyphen." \
    prefixed
configure "$(declared loose v1 skills-repository)"
"$bin/clankos-run" install > ../out 2> ../err
check "A skills-repository's skills keep the names their author gave them." \
    test -f .agents/skills/greet/SKILL.md -a -f .agents/skills/loose-greet/SKILL.md
git checkout -q .clanka/config.yml && rm -rf .agents skills-lock.json
check "No source supplies a skill whose name begins with clankos-." \
    not_reserved

[ "$failures" -eq 0 ]
