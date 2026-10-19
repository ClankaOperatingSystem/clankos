#!/usr/bin/env bash
# Read the tests in test/model/: each is one group of docs/model.txt's
# requirements, and each check and held_by line in it is named by one
# requirement, a whole sentence that reads alone; and docs/model.txt
# lists them as scripts/render-model writes them.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"

# names FILE: the requirement each check and held_by line of FILE names,
# one a line.
names() {
    sed -n -e 's/^check "\([^"]*\)".*/\1/p' -e 's/^held_by "[^"]*" "\([^"]*\)".*/\1/p' "$1"
}
# sentences FILE: whether every name in FILE ends with a full stop,
# holds no expansion, and does not begin as the rest of another does,
# with a word such as "and" or "which".
sentences() {
    ! names "$1" | grep -v '^[^$]*\.$' | grep -q . \
        && ! names "$1" | grep -Eq '^(and|or|but|with|while|which|then|as|so) '
}

for test in "$repo"/test/model/*.sh; do
    name=$(basename -- "$test" .sh)
    check "$name names at least one requirement" grep -Eq '^(check|held_by) "' "$test"
    check "$name names each requirement as a sentence" sentences "$test"
done

check "docs/model.txt holds the requirements as test/model/ names them" \
    "$repo/scripts/render-model" --check

[ "$failures" -eq 0 ]
