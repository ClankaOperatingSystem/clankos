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
check "the intray is still the invoking user's" test "$(owner intray.org)" = "$(id -u)"
check "no lock or backup file is left" test "$(ls -A | sort | tr '\n' ' ')" = ".pos err intray.org out "

"$bin/pos-capture" -- "It's \"quoted\" \$HOME" >/dev/null 2>&1
check "a title is kept as written" grep -qF "** TODO It's \"quoted\" \$HOME" intray.org

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

[ "$failures" -eq 0 ]
