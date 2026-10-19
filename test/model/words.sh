#!/usr/bin/env bash
# The words documents: docs/words.txt here and docs/words.md in bugflow,
# each giving a word one line that names where the word is defined.
# Reads the documents only; the image is not run.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
. "$repo/test/lib/model.sh"
. "$repo/test/lib/words.sh"

words=$repo/docs/words.txt
entries "$words" 23 > entries

check "clankos's words document is docs/words.txt." test -s entries
held_by "bugflow's tests" "bugflow's words document is docs/words.md."
once() { [ -z "$(cut -f1 entries | sort | uniq -d)" ]; }
check "A words document gives each word one line." once
# A line names a document by "clankos-run help", with or without a
# NAME, by "help NAME", by a web address or by a path under docs/.
named() { ! cut -f2 entries | grep -qvE '"(clankos-run )?help[ "]|https://|docs/'; }
check "A word's line names the document, and the section where there is one, that defines the word." \
    named
exist() {
    local name
    for name in $(grep -ho '"help [a-z-]*"' "$words" | sed 's/^"help \(.*\)"$/\1/' | sort -u); do
        [ -f "$repo/docs/$name.txt" ] || return 1
    done
}
check "The document and section that a word's line names exist." exist

[ "$failures" -eq 0 ]
