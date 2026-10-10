#!/usr/bin/env bash
# Run bin/pos-place against a new workspace.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

mkdir .pos
cat > intray.org <<'ORG'
* Unsorted
** TODO Call the roofer
:PROPERTIES:
:ID:       roofer
:END:
The gutter leaks.
*** TODO Find the number
** TODO Sort the shelf
See [[*Call the roofer]].
ORG
cat > tasks.org <<'ORG'
* Tasks
** NEXT Mend the house :home:
* Notes
[[file:intray.org::*Call the roofer][by file]] [[id:roofer][by ID]]
ORG

"$bin/pos-place" roofer tasks.org 'Tasks/Mend the house' NEXT > out 2> err
check "the task is reported where it now is" \
    grep -qx "$work/tasks.org:3: NEXT Call the roofer" out
check "it has left its file" sh -c '! grep -q "Call the roofer$" intray.org'
check "it is beneath the heading named, at that level" grep -qx '\*\*\* NEXT Call the roofer' tasks.org
check "with its properties" grep -q '^:ID: *roofer$' tasks.org
check "its body" grep -qx 'The gutter leaks.' tasks.org
check "and its child" grep -qx '\*\*\*\* TODO Find the number' tasks.org
check "the move is recorded with where it came from" \
    sh -c "grep -q '^- Refiled on \[' tasks.org && grep -qx '  From intray.org, Unsorted' tasks.org"
check "and the change of state" grep -q '^- State "NEXT" *from "TODO"' tasks.org
check "each link that names the old place is printed" \
    test "$(grep -c '^Link to the old place: ' out)" = 2
check "one in the old file" grep -q "^Link to the old place: $work/intray.org:" out
check "and one in another" grep -q "^Link to the old place: $work/tasks.org:" out
check "no lock or backup file is left" \
    test "$(ls -A | sort | tr '\n' ' ')" = ".pos err intray.org out tasks.org "

cp tasks.org before
check "a heading that is not there is refused" \
    sh -c "! '$bin/pos-place' roofer tasks.org 'Tasks/Absent' >/dev/null 2>&1"
check "a heading within the task is refused" \
    sh -c "! '$bin/pos-place' roofer tasks.org 'Tasks/Mend the house/Call the roofer' >/dev/null 2>&1"
check "a refusal writes nothing" cmp -s before tasks.org
check "two arguments are usage" status 2 "$bin/pos-place" roofer tasks.org
check "help needs no container" status 0 env CLANKOS_IMAGE=none.invalid/none "$bin/pos-place" --help

[ "$failures" -eq 0 ]
