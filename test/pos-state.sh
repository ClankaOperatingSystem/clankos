#!/usr/bin/env bash
# Run bin/pos-state against a new workspace.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

mkdir .pos
yesterday=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d yesterday +%Y-%m-%d)
cat > tasks.org <<ORG
* TODO Call the roofer
:PROPERTIES:
:ID:       roofer
:END:
* TODO Weekly review :review:
SCHEDULED: <$yesterday ++1w>
* NEXT Pay the bill
ORG

"$bin/pos-state" roofer WAITING 'Asked by phone' > out 2> err
check "the task is named by its ID, and reported as it now is" \
    grep -qx "$work/tasks.org:1: WAITING Call the roofer" out
check "the change is recorded in its LOGBOOK" \
    grep -q '^- State "WAITING" *from "TODO" *\[' tasks.org
check "with the note" grep -qx '  Asked by phone' tasks.org
check "an open state adds no closing date" sh -c '! grep -q "^CLOSED:" tasks.org'

line=$(grep -n 'Pay the bill' tasks.org | cut -d: -f1)
"$bin/pos-state" "tasks.org:$line" DONE > out 2> err
check "the task is named by its file and line" grep -q "DONE Pay the bill\$" out
check "a done state adds the closing date" grep -q '^CLOSED: \[' tasks.org

line=$(grep -n 'Weekly review' tasks.org | cut -d: -f1)
"$bin/pos-state" "tasks.org:$line" DONE 'Reviewed' > out 2> err
check "a repeating task set done is open again" grep -q "TODO Weekly review\$" out
check "on a later date" sh -c "! grep -q 'SCHEDULED: <$yesterday' tasks.org"
check "and the change is recorded" grep -q '^- State "DONE" *from "TODO"' tasks.org
check "the file is still the invoking user's" test "$(owner tasks.org)" = "$(id -u)"
check "no lock or backup file is left" test "$(ls -A | sort | tr '\n' ' ')" = ".pos err out tasks.org "

cp tasks.org before
check "a state that is not one is refused" sh -c "! '$bin/pos-state' roofer BLOCKED >/dev/null 2>&1"
check "the state the task has is refused" sh -c "! '$bin/pos-state' roofer WAITING >/dev/null 2>&1"
check "an ID no heading has is refused" sh -c "! '$bin/pos-state' absent DONE >/dev/null 2>&1"
check "a refusal writes nothing" cmp -s before tasks.org
check "one argument is usage" status 2 "$bin/pos-state" roofer
check "help needs no container" status 0 env CLANKOS_IMAGE=none.invalid/none "$bin/pos-state" --help

[ "$failures" -eq 0 ]
