#!/usr/bin/env bash
# Run bin/pos-capture against a new workspace.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

mkdir .pos
printf '#+TITLE: Intray\n' > intray.org

"$bin/pos-capture" -- 'Make time for sketching' > out 2> err
check "capture reports the file, line and title" \
    grep -q "^$work/intray.org:3: TODO Make time for sketching\$" out
check "capture makes Unsorted" grep -q '^\* Unsorted$' intray.org
check "capture adds the task" grep -q '^\*\* TODO Make time for sketching$' intray.org
check "the task has an ID" grep -Eq '^:ID: +[0-9a-f-]{36}$' intray.org
check "and the time it was captured" \
    grep -Eq "^:CREATED: +\[$(date +%Y-%m-%d) [A-Z][a-z]{2} [0-9]{2}:[0-9]{2}\]\$" intray.org
check "nothing is like the first task" sh -c '! grep -q "^Like:" out'
check "the intray is still the invoking user's" test "$(owner intray.org)" = "$(id -u)"
check "no lock or backup file is left" test "$(ls -A | sort | tr '\n' ' ')" = ".pos err intray.org out "

"$bin/pos-capture" -- "It's \"quoted\" \$HOME" >/dev/null 2>&1
check "a title is kept as written" grep -qF "** TODO It's \"quoted\" \$HOME" intray.org

"$bin/pos-capture" -- 'Make time for sketching' > again 2>/dev/null
check "a like title is reported, with where it is" \
    grep -q "^Like: $work/intray.org:3: TODO Make time for sketching\$" again
check "and the task is added all the same" \
    test "$(grep -c '^\*\* TODO Make time for sketching$' intray.org)" = 2
rm -f again

"$bin/pos-capture" -- 'Call the roofer' 'The gutter leaks.

By the door.' >/dev/null 2>&1
check "a body is written beneath the task's properties" \
    sh -c "grep -A8 'TODO Call the roofer' intray.org | tr '\n' '|' | grep -q ':END:|The gutter leaks.||By the door.|'"
check "a body that would make a heading is refused" \
    sh -c "! '$bin/pos-capture' -- 'A task' '* A heading' >/dev/null 2>&1"
cp intray.org before
"$bin/pos-capture" --check -- 'Call roofer' > again 2>/dev/null
check "--check prints the like tasks" grep -q "^Like: .*TODO Call the roofer\$" again
check "and saves nothing" cmp -s before intray.org
check "--check takes no body" status 2 "$bin/pos-capture" --check -- 'Call roofer' 'A body'
rm -f again before

mkdir scope
printf '#+TITLE: Scope intray\n' > scope/intray.org
(cd scope && "$bin/pos-capture" -- 'In the scope' >/dev/null 2>&1)
check "the intray is the working directory's" grep -q 'In the scope' scope/intray.org

mkdir empty
check "a missing intray is refused" \
    sh -c "cd empty && ! '$bin/pos-capture' -- 'Nowhere to go' >/dev/null 2>&1"
check "a refusal makes no intray" test ! -e empty/intray.org
check "an empty title is refused" sh -c "! '$bin/pos-capture' -- ' ' >/dev/null 2>&1"
check "a title without -- is usage" status 2 "$bin/pos-capture" 'No dashes'
check "and is told to put -- before the title" \
    sh -c "'$bin/pos-capture' 'No dashes' 2>&1 | grep -qx 'pos-capture: put -- before the title'"

[ "$failures" -eq 0 ]
