#!/usr/bin/env bash
# Run bin/pos-refile against a new workspace.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

mkdir .pos work attic
echo "(setq pos-refile-rules '((\"invoice\" . \"work/todo.org\")))" > pos-config.el
printf '#+TITLE: Intray\n\n* Unsorted\n** TODO Send the invoice\n** TODO Buy milk\n' > intray.org
printf '#+TITLE: Work\n\n* Tasks\n' > work/todo.org
# A task in a directory no command reads is stranded.
printf '#+TITLE: A note\n\n* Thinking\n** TODO Call the plumber\n' > attic/note.org

"$bin/pos-refile" stranded --dry-run > out 2>/dev/null
check "a dry run names the stranded task" grep -q 'attic/note.org:4 Call the plumber' out
check "a dry run changes nothing" grep -q 'Call the plumber' attic/note.org

"$bin/pos-refile" stranded >/dev/null 2>&1
check "stranded moves the task to the intray" grep -q '^\*\* TODO Call the plumber$' intray.org
check "stranded links back to where it was" grep -qF '[[file:attic/note.org::*Thinking]' intray.org
check "stranded takes the task from its file" sh -c '! grep -q "Call the plumber" attic/note.org'

"$bin/pos-refile" plan > out 2>/dev/null
check "plan reports the entries written" grep -q '^3 intray entries written to refile.org$' out
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
    sh -c "cd empty && '$bin/pos-refile' stranded >/dev/null 2>&1; [ \$? -eq 2 ]"
check "a refusal makes no intray" test ! -e empty/intray.org
check "an unknown command is usage" status 2 "$bin/pos-refile" bogus

[ "$failures" -eq 0 ]
