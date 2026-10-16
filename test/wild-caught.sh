#!/usr/bin/env bash
# Run wild-caught against a garden and a responsibility mounted in it,
# each with a skills-lock.json written for the test.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.org
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.org

# lock NAME:SOURCE ...: a skills-lock.json recording each.
lock() {
    local first=1
    printf '{"version": 1, "skills": {'
    for entry in "$@"; do
        [ -n "$first" ] || printf ', '
        first=
        printf '"%s": {"source": "%s", "sourceType": "git", "ref": "v1", "computedHash": "0"}' \
            "${entry%%:*}" "${entry#*:}"
    done
    printf '}}\n'
}

mkdir -p child/.clanka && git -C child init -q -b master
printf 'pos: 2\nprojects: projects/\n' > child/.clanka/config.yml
lock tools-lint:https://example.org/tools.git > child/skills-lock.json
git -C child add . && git -C child commit -qm 'Add a responsibility'

mkdir -p garden/.clanka && cd garden && git init -q -b master
printf 'pos: 2\nprojects: projects/\nmethodologies:\n  - source: https://example.org/kept.git\n    ref: v1\nchildren:\n  - path: child\n    remote: %s\n' \
    "$work/child" > .clanka/config.yml
lock grill-me:someone/skills kept-one:https://example.org/kept.git > skills-lock.json
git clone -q "$work/child" child
git add .clanka skills-lock.json && git commit -qm 'Add a garden'

"$bin/clankos-run" wild-caught > ../out 2> ../err
check "wild-caught succeeds" test $? -eq 0
check "and lists each node's, beneath its directory" \
    test "$(cat ../out)" = '.
  grill-me: from someone/skills, which is not declared
child
  tools-lint: from https://example.org/tools.git, which is not declared'
check "and prints nothing else" test ! -s ../err
check "and changes nothing" sh -c 'git diff --quiet && test ! -e .clanka/auto' 

(cd child && "$bin/clankos-run" wild-caught > ../../out 2> ../../err)
check "from a mounted repository, its own" \
    test "$(cat ../out)" = '.
  tools-lint: from https://example.org/tools.git, which is not declared'

printf 'pos: 9\n' > child/.clanka/config.yml && git -C child commit -qam 'Refuse'
"$bin/clankos-run" wild-caught > ../out 2> ../err
check "a refused configuration exits 1" test $? -eq 1
check "and is reported" grep -q '^wild-caught: config-refused ' ../err
cd ..

[ "$failures" -eq 0 ]
