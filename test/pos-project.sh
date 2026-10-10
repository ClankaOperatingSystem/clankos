#!/usr/bin/env bash
# Run bin/pos-project against a new garden.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

git init -q .
"$bin/initiate" --no-tree < /dev/null > out 2>&1
"$bin/responsibility-tree" --responsibility health > out 2>&1

"$bin/pos-project" create . mend-roof 'Mend the roof' 'The roof does not leak.' \
    2030-03-01 'Call the roofer' > out 2> err
check "create prints the file made" grep -qx 'projects/mend-roof.org' out
check "the file has an ID" grep -Eq '^:ID: +[0-9A-Fa-f-]{36}$' projects/mend-roof.org
check "the status of a project not begun" grep -q '^:STATUS: *COMMITTED$' projects/mend-roof.org
check "its outcome, as a property" \
    grep -Eq '^:OUTCOME: +The roof does not leak\.$' projects/mend-roof.org
check "and no Outcome heading" sh -c "! grep -q '^\* Outcome' projects/mend-roof.org"
check "its next action" grep -qx '\* NEXT Call the roofer' projects/mend-roof.org
check "and its review, scheduled" grep -qx 'SCHEDULED: <2030-03-01 Fri>' projects/mend-roof.org
"$bin/startup-prompt" --view projects > out 2> err
check "startup-prompt lists the project with what it was made with" \
    sh -c "grep -q 'projects/mend-roof *COMMITTED *review 2030-03-01' out && grep -q 'outcome: The roof does not leak.' out"

"$bin/pos-project" create health checkup 'Have a checkup' 'Seen by the doctor.' 2030-04-01 > out 2> err
check "a responsibility's project goes where its projects belong" \
    test -f health/projects/checkup.org
check "an outcome of two lines is refused" \
    sh -c "! '$bin/pos-project' create . two-lines 'Two' 'One.
Two.' 2030-03-01 >/dev/null 2>&1"
check "a name that is taken is refused" \
    sh -c "! '$bin/pos-project' create . mend-roof 'Again' 'Outcome.' 2030-03-01 >/dev/null 2>&1"

"$bin/pos-project" status projects/mend-roof WIP 'Rang the roofer' > out 2> err
check "status prints the file and both statuses" \
    grep -qx 'projects/mend-roof.org: STATUS WIP, was COMMITTED' out
check "the status is changed" grep -q '^:STATUS: *WIP$' projects/mend-roof.org
check "and the change recorded, with the note" \
    sh -c "grep -q '^- Status \"WIP\" *from \"COMMITTED\"' projects/mend-roof.org && grep -qx '  Rang the roofer' projects/mend-roof.org"
check "a status that is not one is refused" \
    sh -c "! '$bin/pos-project' status projects/mend-roof BEGUN >/dev/null 2>&1"

printf 'See [[file:projects/mend-roof.org][the roof]].\n' >> intray.org
"$bin/pos-project" promote projects/mend-roof > out 2> err
check "promote prints the new file" grep -qx 'projects/mend-roof/project.org' out
check "the file has moved" test -f projects/mend-roof/project.org -a ! -e projects/mend-roof.org
check "a link to it is rewritten" grep -qF '[[file:projects/mend-roof/project.org][the roof]]' intray.org
check "and reported" grep -qx 'Links rewritten: intray.org: 1' out
check "a project that is a directory already is refused" \
    sh -c "! '$bin/pos-project' promote projects/mend-roof >/dev/null 2>&1"
check "a command that is not one is usage" status 2 "$bin/pos-project" retire projects/mend-roof
check "help needs no container" status 0 env CLANKOS_IMAGE=none.invalid/none "$bin/pos-project" --help

[ "$failures" -eq 0 ]
