#!/usr/bin/env bash
# Run clankos-run help, from this repository, against the image. The
# launcher's own cases each start a container; every document is
# printed by the image's help in one container more.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"

mkdir .clanka

"$bin/clankos-run" help > out 2> err
check "help prints the image's account of a garden" cmp -s out "$repo/docs/clankos.txt"

for doc in "$repo"/docs/*.txt; do
    name=$(basename -- "$doc" .txt)
    printf '== %s\n' "$name"
    cat "$doc"
done > expected
docker run --rm --entrypoint sh "$CLANKOS_IMAGE" -c '
    for doc in /usr/local/share/clankos/docs/*.txt; do
        name=${doc##*/}
        name=${name%.txt}
        printf "== %s\n" "$name"
        /usr/local/libexec/clankos/help "$name" || exit 1
    done' > out 2> err
check "help prints each document of the repository, and no other" cmp -s out expected

"$bin/clankos-run" help no-such-command > out 2> err
check "a command with no document is refused" test $? -eq 2
check "the refusal lists those there are" grep -qx '  pos-capture' err
check "and prints nothing" test ! -s out
check "a path is no document" status 2 "$bin/clankos-run" help ../bin/clankos-run
check "two commands are usage" status 2 "$bin/clankos-run" help initiate pos-capture

[ "$failures" -eq 0 ]
