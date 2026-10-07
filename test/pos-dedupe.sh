#!/usr/bin/env bash
# Run bin/pos-dedupe against a new workspace.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

mkdir .pos work
echo "(setq pos-pillars '(\"work\"))" > pos-config.el
printf '#+TITLE: Intray\n\n* Unsorted\n** TODO Buy milk\n:PROPERTIES:\n:ID: milk-intray\n:END:\nTwo litres.\n** TODO Water the plants\n' > intray.org
printf '#+TITLE: Work\n\n* Tasks\n** TODO Buy milk\n:PROPERTIES:\n:ID: milk-work\n:END:\nFrom the shop.\n' > work/todo.org
printf ':PROPERTIES:\n:ID: notes\n:END:\n#+TITLE: Notes\n\nSee [[id:milk-intray][the milk]].\n' > notes.org

"$bin/pos-dedupe" plan > out 2>/dev/null
check "plan reports the groups written" grep -q '^1 duplicate groups written to dedupe.org$' out
check "plan has a group for the duplicated task" grep -q '^\* Buy milk$' dedupe.org
check "plan suggests one keep" test "$(grep -c '^| keep ' dedupe.org)" = 1
check "plan suggests one drop" test "$(grep -c '^| drop ' dedupe.org)" = 1
check "plan changes no task" test "$(cat intray.org work/todo.org | grep -c 'Buy milk')" = 2
check "plan lists the links to a copy" grep -q '^- Links to intray.org:4 from notes.org:6$' dedupe.org
check "plan keeps the index in the cache" test -n "$(ls "${XDG_CACHE_HOME:-$HOME/.cache}"/pos/org-roam/*.db 2>/dev/null)"

# The review: keep the copy in work/, drop the intray's.
printf '* Buy milk\n| keep | work/todo.org | 4 |\n| drop | intray.org | 4 |\n' > reviewed.org
"$bin/pos-dedupe" apply --dry-run reviewed.org > out 2>/dev/null
check "an apply dry run reports" grep -q '^Would resolve 1 duplicate group (1 merged' out
check "an apply dry run changes nothing" grep -q 'Buy milk' intray.org

"$bin/pos-dedupe" apply reviewed.org > out 2>/dev/null
check "apply reports" grep -q '^Resolved 1 duplicate group (1 merged, 1 links relinked' out
check "apply points the link at the kept copy" grep -q '\[\[id:milk-work\]\[the milk\]\]' notes.org
check "apply leaves the merged note without the dropped ID" sh -c '! grep -q "milk-intray" work/todo.org'
check "apply removes the dropped copy" sh -c '! grep -q "Buy milk" intray.org'
check "apply keeps the kept copy" grep -q '^\*\* TODO Buy milk$' work/todo.org
check "apply merges the dropped copy's differing body" grep -q 'Two litres.' work/todo.org
check "apply leaves other tasks" grep -q 'Water the plants' intray.org

printf '* Water the plants\n| ? | intray.org | 4 |\n' > undecided.org
"$bin/pos-dedupe" apply undecided.org > out 2>/dev/null
check "a group with no keep is skipped" grep -q '1 skipped as undecided' out
check "an unknown command is usage" status 2 "$bin/pos-dedupe" bogus

[ "$failures" -eq 0 ]
