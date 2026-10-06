#!/usr/bin/env bash
# Run bin/responsibility-tree against a new garden.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

mkdir -p garden/.clanka && cd garden && git init -q .
printf 'pos: 2\nprojects: projects/\n' > .clanka/config.yml

"$bin/responsibility-tree" --responsibility health --responsibility work --project kitchen \
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
check "a product is not cloned, and is reported as to clone" \
    sh -c 'test ! -e vendor/lib && grep -qx "to clone  vendor/lib" out && grep -qx "to clone  work/widget" out'
check "poslib's plan finds nothing wrong" sh -c '! grep -q "^finding" out'
check "new responsibilities have ignored archives before they exist" \
    sh -c 'git check-ignore -q health/archives/evidence && git check-ignore -q work/archives/evidence'
check "a responsibility itself is not ignored" sh -c '! git check-ignore -q health/intray.org'

cp .clanka/config.yml before
"$bin/responsibility-tree" --responsibility health --project kitchen \
    --product vendor/lib=https://example.org/lib.git >/dev/null 2>&1
check "what is there already is kept" cmp -s before .clanka/config.yml
rm before

check "a name that climbs is refused, and the rest done" \
    sh -c "'$bin/responsibility-tree' --responsibility ../out --responsibility play >/dev/null 2>&1; [ \$? -eq 1 ] && test -d play && test ! -e ../out"

(cd work && "$bin/responsibility-tree" --responsibility clients >/dev/null 2>&1)
check "run in a responsibility, it adds beneath that one" \
    sh -c "test -f work/clients/.clanka/config.yml && grep -qx '  - path: clients' work/.clanka/config.yml"
check "a nested responsibility's archive is ignored" git check-ignore -q work/clients/archives/evidence

printf 'garden-two\n\nbook\n\n\n' | "$bin/responsibility-tree" --ask >/dev/null 2>&1
check "--ask reads the answers from standard input" test -d garden-two -a -f projects/book.org

# A directory removed on the host can still be seen in a container for
# a moment, where the host's files reach Docker through a virtual
# machine. Look until it is seen to be gone.
rm -rf play
for _ in 1 2 3 4 5 6 7 8 9 10; do
    "$bin/responsibility-tree" --project another > out 2>&1
    ! grep -qx 'finding   missing play' out || break
    sleep 1
done
check "a declared directory that is gone is a finding" grep -qx 'finding   missing play' out
rm out
cd ..

mkdir plain && (cd plain && git init -q .)
check "a repository that is no garden is refused" \
    sh -c "cd plain && '$bin/responsibility-tree' --project x >/dev/null 2>&1; [ \$? -eq 2 ]"

[ "$failures" -eq 0 ]
