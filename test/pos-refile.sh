#!/usr/bin/env bash
# Run bin/pos-refile against a new workspace.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

mkdir .pos work
echo "(setq pos-refile-rules '((\"invoice\" . \"work/todo.org\")))" > pos-config.el
printf '#+TITLE: Intray\n\n* Unsorted\n** TODO Send the invoice\n** TODO Buy milk\n' > intray.org
printf '#+TITLE: Work\n\n* Tasks\n' > work/todo.org

"$bin/pos-refile" plan > out 2>/dev/null
check "plan reports the entries written" grep -q '^2 intray entries written to refile.org$' out
check "plan suggests the rule's file" \
    grep -q '^| move *| *4 *| Send the invoice *| work/todo.org ' refile.org
check "plan leaves the rest undecided" grep -q '^| ? *| *5 *| Buy milk ' refile.org
check "plan changes no intray" grep -q 'Send the invoice' intray.org

# The review: the reviewer names the file and the heading.
printf '| move | 4 | Send the invoice | work/todo.org | Tasks | |\n| ? | 5 | Buy milk | | | |\n' > reviewed.org
"$bin/pos-refile" apply --dry-run reviewed.org > out 2>/dev/null
check "an apply dry run reports" grep -q '^Would refile 1 intray entry' out
check "an apply dry run changes nothing" grep -q 'Send the invoice' intray.org

"$bin/pos-refile" apply reviewed.org > out 2>/dev/null
check "apply reports" grep -q '^Refiled 1 intray entry' out
check "apply moves the entry to its target" grep -q '^\*\* TODO Send the invoice$' work/todo.org
check "apply takes the entry from the intray" sh -c '! grep -q "Send the invoice" intray.org'
check "apply leaves an undecided entry" grep -q 'Buy milk' intray.org

mkdir empty
check "a directory without an intray is refused" \
    sh -c "cd empty && '$bin/pos-refile' plan >/dev/null 2>&1; [ \$? -eq 2 ]"
check "a refusal makes no intray" test ! -e empty/intray.org
check "an unknown command is usage" status 2 "$bin/pos-refile" bogus
check "stranded is no longer a command" status 2 "$bin/pos-refile" stranded

[ "$failures" -eq 0 ]
