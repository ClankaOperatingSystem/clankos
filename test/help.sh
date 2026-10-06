#!/usr/bin/env bash
# Run clankos-run help, from this repository, against the image.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

mkdir .clanka

"$bin/clankos-run" help > out 2> err
check "help prints the image's account of a garden" cmp -s out "$repo/docs/clankos.txt"
for script in "$bin"/*; do
    name=${script##*/}
    check "it lists $name" grep -q "^    $name " out
done

for doc in "$repo"/docs/*.txt; do
    name=$(basename -- "$doc" .txt)
    "$bin/clankos-run" help "$name" > out 2> err
    check "help $name prints its document" cmp -s out "$doc"
done
for script in "$bin"/*; do
    name=${script##*/}
    case $name in
        clankos-run|install.sh) continue ;;
    esac
    check "$name has a document" test -f "$repo/docs/$name.txt"
    check "$name --help names it" sh -c "'$script' --help | grep -qF '\"clankos-run help $name\"'"
done

"$bin/clankos-run" help no-such-command > out 2> err
check "a command with no document is refused" test $? -eq 2
check "the refusal lists those there are" grep -qx '  pos-capture' err
check "and prints nothing" test ! -s out
check "a path is no document" status 2 "$bin/clankos-run" help ../bin/clankos-run
check "two commands are usage" status 2 "$bin/clankos-run" help initiate pos-capture

[ "$failures" -eq 0 ]
