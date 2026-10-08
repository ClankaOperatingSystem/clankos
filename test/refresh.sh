#!/usr/bin/env bash
# Run refresh, alone and before another command, against new gardens.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.org
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.org

mkdir -p product && git -C product init -q -b master
printf 'A product.\n' > product/README
git -C product add . && git -C product commit -qm 'Add a product'
mkdir -p child/.clanka && git -C child init -q -b master
printf 'pos: 2\nprojects: projects/\n' > child/.clanka/config.yml
git -C child add . && git -C child commit -qm 'Add a responsibility'

mkdir -p garden/.clanka && cd garden && git init -q -b master
printf 'pos: 2\nprojects: projects/\nbin: bin\nchildren:\n  - path: child\n    remote: %s\n  - path: product\n    remote: %s\n' \
    "$work/child" "$work/product" > .clanka/config.yml
printf '#+TITLE: Intray\n\n* Unsorted\n' > intray.org
git clone -q "$work/child" child
git clone -q "$work/product" product
git add .clanka intray.org && git commit -qm 'Add a garden'

"$bin/clankos-run" refresh > ../out 2> ../err
check "refresh succeeds" test $? -eq 0
check "and prints nothing" test ! -s ../out -a ! -s ../err
check "the garden has the image's scripts installed" cmp -s .clanka/auto/bin/clankos-run "$bin/clankos-run"
check "and a link to each where it says bin" test "$(readlink bin/pos-capture)" = ../.clanka/auto/bin/pos-capture
check "a mounted responsibility has them installed too" test -x child/.clanka/auto/bin/clankos-run
check "with no links where it names no bin" test ! -e child/bin
check "nothing is written in a product" test "$(ls -A product)" = ".git
README"
check "no repository sees a change" \
    test -z "$(git status --porcelain)$(git -C child status --porcelain)$(git -C product status --porcelain)"

printf 'scribble\n' > .clanka/auto/scribble
printf 'an older version\n' > .clanka/auto/version
rm bin/pos-capture
"$bin/clankos-run" pos-capture -- 'A task' > ../out 2> ../err
check "a command runs refresh first: another version is replaced whole" test ! -e .clanka/auto/scribble
check "and a missing link is made" test -L bin/pos-capture
check "and the command then runs" grep -q 'A task' intray.org

rm bin/pos-capture && printf 'mine\n' > bin/pos-capture
"$bin/clankos-run" refresh > ../out 2> ../err
check "a name that is taken exits 1" test $? -eq 1
check "and is named on stderr" grep -qx 'clankos: name-taken bin/pos-capture (untracked)' ../err
check "what has the name is left" test "$(cat bin/pos-capture)" = mine
"$bin/clankos-run" startup-prompt --view next > ../out 2> ../err
check "it is said again before every command" grep -q '^clankos: name-taken bin/pos-capture' ../err
check "and the command runs all the same" grep -q 'START-UP PROMPTS' ../out
cd ..

mkdir plain
check "outside a repository refresh does nothing" sh -c "cd plain && CLANKOS_WORKSPACE='$work/plain' '$bin/clankos-run' refresh"

[ "$failures" -eq 0 ]
