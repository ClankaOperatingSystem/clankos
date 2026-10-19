#!/usr/bin/env bash
# Words coverage: each thing a model names has a line in its
# repository's words document, and a word both models name is defined
# in one of the two. bugflow is cloned from GitHub at its default
# branch, or at BUGFLOW_BRANCH where that is set. The image is not run.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
. "$repo/test/lib/model.sh"
. "$repo/test/lib/words.sh"

entries "$repo/docs/words.txt" 23 > ours
sed -n '/^1\. The things/,/^2\. /p' "$repo/docs/model.txt" | entries /dev/stdin 22 | cut -f1 > our-things

covered() {
    local thing
    while read -r thing; do
        cut -f1 ours | grep -qxF "$thing" || return 1
    done < our-things
}
check "Each thing that clankos's model names has a line in clankos's words document." covered
held_by "bugflow's tests" "Each thing that bugflow's model names has a line in bugflow's words document."

git clone -q --depth 1 ${BUGFLOW_BRANCH:+--branch "$BUGFLOW_BRANCH"} \
    https://github.com/bugflow/bugflow.git bugflow 2>/dev/null
bugflow_entries bugflow/docs/words.md > theirs 2>/dev/null
sed -n '/^things = \[/,/^\]/p' bugflow/docs/model.toml 2>/dev/null | grep -o '"[^"]*"' | tr -d '"' > their-things
grep -xF -f our-things their-things > shared

# line WORD FILE: the text of WORD's line in FILE.
line() { awk -F '\t' -v word="$1" '$1 == word { print $2 }' "$2"; }
# For each word both name: a line in each, and exactly one of the two
# names the other's words document.
one_owner() {
    local word ours_points theirs_points
    [ -s shared ] || return 1
    while read -r word; do
        [ -n "$(line "$word" ours)" ] && [ -n "$(line "$word" theirs)" ] || return 1
        ours_points=0 theirs_points=0
        line "$word" ours | grep -q 'docs/words\.md' && ours_points=1
        line "$word" theirs | grep -q 'docs/words\.txt' && theirs_points=1
        [ $((ours_points + theirs_points)) -eq 1 ] || return 1
    done < shared
}
check "A word that both models name has its line in one words document." one_owner
# The line that does not define the word links the other's words
# document: bugflow's by its address on GitHub, this one's by name.
links() {
    local word
    [ -s shared ] || return 1
    while read -r word; do
        if line "$word" ours | grep -q 'docs/words\.md'; then
            line "$word" ours | grep -q "bugflow's word, in its docs/words\.md" || return 1
        else
            line "$word" theirs | grep -q 'github\.com/ClankaOperatingSystem/clankos/blob/master/docs/words\.txt' || return 1
        fi
    done < shared
}
check "The other words document links to that line for that word." links

[ "$failures" -eq 0 ]
