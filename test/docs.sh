#!/usr/bin/env bash
# Check that the documents under docs/ refer to documents that are there:
# every "clankos-run help NAME" names docs/NAME.txt, and every section a
# reference gives, as ("clankos-run help NAME", N), is a section of it.
# Reads the repository only; the image is not run.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

docs=$repo/docs

# Every help reference names a document.
grep -ho '"clankos-run help[^"]*"' "$docs"/*.txt | sort -u | while read -r ref; do
    name=$(printf '%s' "$ref" | sed -n 's/^"clankos-run help \([a-z-]*\)"$/\1/p')
    [ -z "$name" ] && name=clankos
    echo "$name"
done | sort -u > names
while read -r name; do
    check "a help reference names docs/$name.txt" test -f "$docs/$name.txt"
done < names

# Every section a reference gives is in the document it names.
grep -ho '("clankos-run help[^)]*", [0-9]*)' "$docs"/*.txt | sort -u | while read -r ref; do
    name=$(printf '%s' "$ref" | sed -n 's/^("clankos-run help \([a-z-]*\)", \([0-9]*\))$/\1/p')
    section=$(printf '%s' "$ref" | sed -n 's/^("clankos-run help[^"]*", \([0-9]*\))$/\1/p')
    [ -z "$name" ] && name=clankos
    echo "$name $section"
done | sort -u > sections
while read -r name section; do
    check "docs/$name.txt has a section $section" grep -q "^$section\. " "$docs/$name.txt"
done < sections

# The words document's short references, "help NAME", name documents too.
grep -ho '"help [a-z-]*"' "$docs/words.txt" | sort -u | sed 's/^"help \(.*\)"$/\1/' | while read -r name; do
    check "words refers to docs/$name.txt" test -f "$docs/$name.txt"
done

[ "$failures" -eq 0 ]
