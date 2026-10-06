#!/usr/bin/env bash
# Run bin/initiate, from this repository, against new Git repositories.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

registry=ghcr.io/clankaoperatingsystem/clankos

mkdir defaults && cd defaults && git init -q .
"$bin/initiate" < /dev/null > out 2>&1
check "with no terminal it takes the defaults" \
    test "$(cat .clanka/config.yml)" = "pos: 2
projects: projects/
image: $registry:latest"
check "an uncommitted archive is ignored by Git" grep -qxF '/archives/' .gitignore
check "underscore directories are ignored by Git" grep -qxF '_*/' .gitignore
check "the intray has Unsorted" grep -qx '\* Unsorted' intray.org
check "it gives the garden the image's scripts" \
    sh -c 'for s in archive-integrity clankos-run initiate pos-capture responsibility-tree startup-prompt; do [ -x "bin/$s" ] || exit 1; done'
check "the scripts are those of this repository" cmp -s bin/clankos-run "$bin/clankos-run"
check "it commits nothing" test -z "$(git log --oneline 2>/dev/null)"
check "what it wrote is the invoking user's" test "$(owner .clanka/config.yml)" = "$(id -u)"
rm out

# The garden's own scripts work, in the image it was made with.
check "the garden's own capture works" sh -c "bin/pos-capture -- 'First task' >/dev/null 2>&1 && grep -q 'First task' intray.org"
check "the garden's archive check is clean" status 0 bin/archive-integrity check .

echo "mine" > bin/pos-capture
"$bin/initiate" --image v9 --archive committed < /dev/null > out 2>&1
check "run again, the configuration is kept" grep -qxF "image: $registry:latest" .clanka/config.yml
check "run again, a script that differs is kept" test "$(cat bin/pos-capture)" = mine
check "and is reported" grep -q 'kept      bin/pos-capture (it differs' out
cd ..

mkdir pinned && cd pinned && git init -q . && printf 'node_modules/' > .gitignore
"$bin/initiate" --image v0.0.1 --archive remote --keeper https://keeper.example/ledgers/a < /dev/null >/dev/null 2>&1
check "options answer the questions" \
    test "$(cat .clanka/config.yml)" = "pos: 2
projects: projects/
image: $registry:v0.0.1
archives:
  - scope: \".\"
    kept: remote
    url: https://keeper.example/ledgers/a"
check "a remote archive is not ignored" sh -c '! grep -q archives .gitignore'
check "a line is added to .gitignore on a line of its own" grep -qx 'node_modules/' .gitignore
check "the pinned image is the one the garden runs" \
    sh -c "[ \"\$(env -u CLANKOS_IMAGE bin/clankos-run --show | tail -n 1)\" = 'image $registry:v0.0.1' ]"
cd ..

mkdir asked && cd asked && git init -q .
printf 'v0.0.1\ncommitted\nhealth\n\n\n\n' | "$bin/initiate" --ask >/dev/null 2>&1
check "--ask reads the answers from standard input" \
    test "$(sed -n 3,6p .clanka/config.yml | tr '\n' '|')" = "image: $registry:v0.0.1|archives:|  - scope: \".\"|    kept: committed|"
check "--ask goes on to the tree" test -f health/.clanka/config.yml
cd ..

mkdir elsewhere && cd elsewhere && git init -q . && mkdir tools
"$bin/initiate" --bin tools < /dev/null >/dev/null 2>&1
check "--bin names where the scripts go" test -x tools/clankos-run -a ! -e bin
cd ..

mkdir plain
check "a directory that is no repository is refused" sh -c "cd plain && '$bin/initiate' </dev/null >/dev/null 2>&1; [ \$? -eq 2 ]"
check "a refusal writes nothing" test -z "$(ls -A plain)"
mkdir bad && (cd bad && git init -q .)
check "an archive kept some other way is refused" sh -c "cd bad && '$bin/initiate' --archive elsewhere </dev/null >/dev/null 2>&1; [ \$? -eq 2 ]"
check "a remote archive without a keeper is refused" sh -c "cd bad && '$bin/initiate' --archive remote </dev/null >/dev/null 2>&1; [ \$? -eq 2 ]"
check "a refused answer writes no configuration" test ! -e bad/.clanka

[ "$failures" -eq 0 ]
