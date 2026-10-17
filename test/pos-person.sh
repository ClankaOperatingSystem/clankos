#!/usr/bin/env bash
# Run bin/pos-person against a new workspace.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

mkdir .clanka
printf 'pos: 2\n' > .clanka/config.yml
cat > intray.org <<'ORG'
* Unsorted
** TODO Ask Ada for the quote
:PROPERTIES:
:ID:       quote
:END:
ORG

"$bin/pos-person" add 'Ada Brook' > out 2> err
check "a person is recorded" test "$(cat out)" = .clanka/person-entities/ada-brook.org
check "in a file with an ID" grep -q '^:ID: ' .clanka/person-entities/ada-brook.org

"$bin/pos-person" wait quote 'Ada Brook' 'Asked on Friday' > out 2> err
check "a task waits on the person" grep -qx "intray.org:2: WAITING Ask Ada for the quote" out
check "linked to their identity in its scope" grep -q '^:WAITING_ON: *\[\[id:' intray.org
check "the identity is made" test -n "$(ls .clanka/person-identities/)"
check "with the note kept" grep -q 'Asked on Friday' intray.org

"$bin/pos-person" arrived quote > out 2> err
check "an arrival sets the task to NEXT" grep -qx "intray.org:2: NEXT Ask Ada for the quote" out
check "and removes the link" sh -c '! grep -q WAITING_ON intray.org'

cp intray.org before
check "a person not recorded is refused" \
    sh -c "! '$bin/pos-person' wait quote 'Nobody Here' >/dev/null 2>&1"
check "a refusal writes nothing" cmp -s before intray.org
check "one argument is usage" status 2 "$bin/pos-person" add
check "help needs no container" status 0 env CLANKOS_IMAGE=none.invalid/none "$bin/pos-person" --help

[ "$failures" -eq 0 ]
