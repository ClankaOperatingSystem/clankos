#!/usr/bin/env bash
# Run bin/pos-item against a new workspace.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

mkdir .pos
cat > tasks.org <<ORG
* TODO Call the roofer :home:
:PROPERTIES:
:ID:       roofer
:END:
* NEXT Pay the bill
ORG

"$bin/pos-item" schedule roofer 2031-03-04 > out 2> err
check "a task named by its ID is scheduled, and reported with the date" \
    grep -qx "$work/tasks.org:1: TODO Call the roofer SCHEDULED: <2031-03-04 Tue>" out
check "the date is on the planning line" \
    test "$(sed -n 2p tasks.org)" = 'SCHEDULED: <2031-03-04 Tue>'

"$bin/pos-item" schedule roofer '2031-03-05 +1w' > out 2> err
check "a repeater is written when one is given" \
    test "$(sed -n 2p tasks.org)" = 'SCHEDULED: <2031-03-05 Wed +1w>'

line=$(grep -n 'Pay the bill' tasks.org | cut -d: -f1)
"$bin/pos-item" deadline "tasks.org:$line" 2031-03-31 > out 2> err
check "a task named by its file and line is given a deadline" \
    grep -qx "$work/tasks.org:$line: NEXT Pay the bill DEADLINE: <2031-03-31 Mon>" out
"$bin/pos-item" deadline "tasks.org:$line" none > out 2> err
check "none removes the date" sh -c '! grep -q DEADLINE tasks.org'
check "and the task is reported without one" \
    grep -qx "$work/tasks.org:$line: NEXT Pay the bill" out

"$bin/pos-item" tag roofer +phone -home > out 2> err
check "tags are added and removed, and reported" \
    grep -qx "$work/tasks.org:1: TODO Call the roofer :phone:" out
check "nothing is recorded in a LOGBOOK" sh -c '! grep -q LOGBOOK tasks.org'
check "the file is still the invoking user's" test "$(owner tasks.org)" = "$(id -u)"
check "no lock or backup file is left" test "$(ls -A | sort | tr '\n' ' ')" = ".pos err out tasks.org "

cp tasks.org before
check "a date that is no date is refused" sh -c "! '$bin/pos-item' schedule roofer tomorrow >/dev/null 2>&1"
check "a tag with no sign is refused" sh -c "! '$bin/pos-item' tag roofer phone >/dev/null 2>&1"
check "an ID no heading has is refused" sh -c "! '$bin/pos-item' tag absent +phone >/dev/null 2>&1"
check "a refusal writes nothing" cmp -s before tasks.org
check "a form that is not one is usage" status 2 "$bin/pos-item" close roofer
check "a date and no more is usage" status 2 "$bin/pos-item" schedule roofer
check "help needs no container" status 0 env CLANKOS_IMAGE=none.invalid/none "$bin/pos-item" --help

[ "$failures" -eq 0 ]
