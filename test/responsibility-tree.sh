#!/usr/bin/env bash
# Run bin/responsibility-tree against a new garden.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

mkdir -p garden/.clanka && cd garden && git init -q .
printf 'pos: 2\nprojects: projects/\n' > .clanka/config.yml

"$bin/responsibility-tree" --no-clone --responsibility health --responsibility work --project kitchen \
    --product work/widget=https://example.org/widget.git \
    --product vendor/lib=https://example.org/lib.git > out 2>&1
check "it succeeds" test $? -eq 0
check "a responsibility has a configuration that says so" \
    test "$(cat health/.clanka/config.yml)" = "pos: 2
projects: projects/"
check "a responsibility has an intray" grep -qx '\* Unsorted' health/intray.org
check "a responsibility is declared, with no remote" \
    sh -c "grep -A1 '^  - path: health\$' .clanka/config.yml | tail -n 1 | grep -qv remote"
check "a project is one file where projects belong" grep -qx '#+TITLE: kitchen' projects/kitchen.org
check "a project is committed, in a drawer that begins its file" \
    test "$(sed -n 1,3p projects/kitchen.org | tr '\n' '|')" = ':PROPERTIES:|:STATUS: COMMITTED|:END:|'
check "so startup-prompt lists it as wanting a review" \
    sh -c "'$bin/startup-prompt' --view reviews-to-schedule 2>/dev/null | grep -q '^  projects/kitchen  *COMMITTED\$'"
check "a project is not declared" sh -c '! grep -q kitchen .clanka/config.yml'
check "a product is declared with its remote" \
    sh -c "grep -A1 '^  - path: vendor/lib\$' .clanka/config.yml | grep -qx '    remote: https://example.org/lib.git'"
check "a product beneath a responsibility is declared by it" \
    test "$(cat work/.clanka/config.yml)" = "pos: 2
projects: projects/
children:
  - path: widget
    remote: https://example.org/widget.git"
check "and not by the garden" sh -c '! grep -q widget .clanka/config.yml'
check "with --no-clone a product is not cloned, and is reported as to clone" \
    sh -c 'test ! -e vendor/lib && grep -qx "to clone  vendor/lib" out && grep -qx "to clone  work/widget" out'
check "poslib's plan finds nothing wrong" sh -c '! grep -q "^finding" out'
check "new responsibilities have ignored archives before they exist" \
    sh -c 'git check-ignore -q health/archives/evidence && git check-ignore -q work/archives/evidence'
check "a responsibility itself is not ignored" sh -c '! git check-ignore -q health/intray.org'

cp .clanka/config.yml before
"$bin/responsibility-tree" --no-clone --responsibility health --project kitchen \
    --product vendor/lib=https://example.org/lib.git >/dev/null 2>&1
check "what is there already is kept" cmp -s before .clanka/config.yml
rm before

check "a name that climbs is refused, and the rest done" \
    sh -c "'$bin/responsibility-tree' --no-clone --responsibility ../out --responsibility play >/dev/null 2>&1; [ \$? -eq 1 ] && test -d play && test ! -e ../out"

printf 'image: example.org/clankos:v9\n' >> work/.clanka/config.yml
(cd work && CLANKOS_IMAGE=${CLANKOS_IMAGE:-} "$bin/responsibility-tree" --no-clone --responsibility clients >/dev/null 2>&1)
check "a new responsibility names the image its container runs" \
    grep -qx 'image: example.org/clankos:v9' work/clients/.clanka/config.yml
check "run in a responsibility, it adds beneath that one" \
    sh -c "test -f work/clients/.clanka/config.yml && grep -qx '  - path: clients' work/.clanka/config.yml"
check "a nested responsibility's archive is ignored" git check-ignore -q work/clients/archives/evidence

printf 'garden-two\n\nbook\n\n\n' | "$bin/responsibility-tree" --no-clone --ask >/dev/null 2>&1
check "--ask reads the answers from standard input" test -d garden-two -a -f projects/book.org

# A directory removed on the host can still be seen in a container for
# a moment, where the host's files reach Docker through a virtual
# machine. Look until it is seen to be gone.
rm -rf play
for _ in 1 2 3 4 5 6 7 8 9 10; do
    "$bin/responsibility-tree" --no-clone --project another > out 2>&1
    ! grep -qx 'finding   missing play' out || break
    sleep 1
done
check "a declared directory that is gone is a finding" grep -qx 'finding   missing play' out
rm out
cd ..

# Cloning, with repositories on this machine as the remotes: lib, and
# shared, a responsibility whose configuration declares inner.
remotes=$PWD/remotes
commit() { git -C "$1" -c user.name=Test -c user.email=test@example.org commit -q --allow-empty -m "$2"; }
for name in lib inner shared; do git init -q -b master "$remotes/$name"; done
commit "$remotes/lib" lib
commit "$remotes/inner" inner
mkdir "$remotes/shared/.clanka"
printf 'pos: 2\nprojects: projects/\nchildren:\n  - path: inner\n    remote: %s\n' "$remotes/inner" \
    > "$remotes/shared/.clanka/config.yml"
git -C "$remotes/shared" add .clanka && commit "$remotes/shared" shared

mkdir -p cloning/.clanka && cd cloning && git init -q .
printf 'pos: 2\nprojects: projects/\n' > .clanka/config.yml
"$bin/responsibility-tree" --product vendor/lib="$remotes/lib" --product shared="$remotes/shared" \
    --product gone="$remotes/gone" > out 2>&1
check "a repository that cannot be cloned makes the exit 1" test $? -eq 1
check "and is reported" grep -qx "not cloned gone from $remotes/gone" out
check "a declared repository is cloned, from its remote" \
    test "$(git -C vendor/lib config --get remote.origin.url)" = "$remotes/lib"
check "on its declared branch" test "$(git -C vendor/lib symbolic-ref --short HEAD)" = master
check "and is reported" grep -qx "cloned    vendor/lib from $remotes/lib" out
check "a repository that a cloned one declares is cloned too" \
    test "$(git -C shared/inner config --get remote.origin.url)" = "$remotes/inner"
check "the garden's Git does not see what was cloned" \
    test -z "$(git status --porcelain --untracked-files=all -- vendor shared)"
"$bin/responsibility-tree" > out 2>&1
check "run again, nothing more is cloned" sh -c '! grep -q "^cloned" out'
check "and what cannot be cloned is tried again" grep -qx "not cloned gone from $remotes/gone" out
cd ..

mkdir plain && (cd plain && git init -q .)
check "a repository that is no garden is refused" \
    sh -c "cd plain && '$bin/responsibility-tree' --project x >/dev/null 2>&1; [ \$? -eq 2 ]"

[ "$failures" -eq 0 ]
