#!/usr/bin/env bash
# Run bin/startup-prompt against a new workspace.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

# day N: the date N days from today, as YYYY-MM-DD.
day() {
    date -d "$1 days" +%Y-%m-%d 2>/dev/null || date -v"$(printf '%+d' "$1")"d +%Y-%m-%d
}

mkdir -p .pos projects/alpha projects/beta responsibilities/home responsibilities/garden archives _tmp
printf '* Unsorted\n** NEXT Answer the letter\n' > intray.org
printf ':PROPERTIES:\n:STATUS:   COMMITTED\n:END:\n* NEXT Draft the outline\n* TODO Review Alpha :review:\nSCHEDULED: <%s>\n' \
    "$(day -1)" > projects/alpha/project.org
printf ':PROPERTIES:\n:STATUS:   WIP\n:END:\n* TODO Book the room\nSCHEDULED: <%s>\n* TODO File the return\nDEADLINE: <%s -3d>\n' \
    "$(day 5)" "$(day 40)" > projects/beta/project.org
printf '* TODO Review the home :review:\nSCHEDULED: <%s>\n' "$(day 0)" > responsibilities/home/index.org
printf '* TODO Prune the hedge\n' > responsibilities/garden/index.org
printf '* NEXT Archived\n' > archives/old.org
printf '* NEXT Generated\n' > _tmp/scratch.org
find . -type f ! -name before | sort > before

"$bin/startup-prompt" > out 2>/dev/null
check "the prompts come first" test "$(head -1 out)" = "START-UP PROMPTS"
check "the files read are counted" grep -q '^Files read: 5$' out
check "next lists a NEXT item by its scope" grep -q '^  alpha  *NEXT Draft the outline$' out
check "an archive is not read" sh -c '! grep -q Archived out'
check "an underscore directory is not read" sh -c '! grep -q Generated out'
check "scheduled lists an item in the horizon" grep -q '^  beta  *Scheduled:  *TODO Book the room$' out
check "deadlines lists one beyond its warning" grep -q '^  beta  *Due in  40 days:  *TODO File the return$' out
check "a review scheduled yesterday is one day late" \
    grep -q '^  alpha  *1 days late:  *TODO Review Alpha$' out
check "a review scheduled today is not late" \
    grep -q '^  responsibilities/home/index  *Scheduled:  *TODO Review the home$' out
check "an active project with no review is named" grep -q '^  projects/beta  *WIP$' out
check "a project with a review is not" sh -c '! grep -q "^  projects/alpha " out'
check "a responsibility with no review is named" grep -q '^  responsibilities/garden$' out
check "every TODO item is not printed unasked" sh -c '! grep -q "^All TODO items" out'

"$bin/startup-prompt" --view all > all 2>/dev/null
check "--view all prints every open item" grep -q 'TODO Prune the hedge$' all
check "--view prints only the views named" sh -c '! grep -q "^NEXT items" all'

rm -f out all
check "nothing is written" sh -c 'find . -type f ! -name before | sort | diff - before'
check "an unknown view is usage" status 2 "$bin/startup-prompt" --view bogus

[ "$failures" -eq 0 ]
