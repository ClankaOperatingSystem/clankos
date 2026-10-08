#!/usr/bin/env bash
# Run bin/startup-prompt against a new workspace.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

# day N: the date N days from today, as YYYY-MM-DD.
day() {
    date -d "$1 days" +%Y-%m-%d 2>/dev/null || date -v"$(printf '%+d' "$1")"d +%Y-%m-%d
}

mkdir -p .pos projects/alpha projects/beta/.clanka projects/beta/methodologies/adr \
    responsibilities/home/.clanka responsibilities/garden/.clanka archives _tmp drafts
# The root excludes a directory of its own besides the default ones, and
# declares beta, a project that is a directory with a configuration.
printf 'pos: 2\nprojects: projects/\nexclude:\n  - archives\n  - attic\n  - node_modules\n  - "_*"\n  - ".*"\n  - drafts\nchildren:\n  - path: projects/beta\n' > .pos/config.yaml
# beta uses a methodology, adr, which declares two kinds of canon and
# holds an Org file of its own, which is not beta's.
printf 'pos: 2\nmethodologies: methodologies\nchildren:\n  - path: methodologies/adr\n' > projects/beta/.clanka/config.yml
printf 'methodology: 1\ncanon:\n  - kind: decision\n    at: decisions/\n    format: markdown\n    entrance: decisions/index.json\n  - kind: decision-index\n    at: decisions/index.json\n    format: json\n    derived: true\n' \
    > projects/beta/methodologies/adr/methodology.yaml
printf '* NEXT Inside the methodology\n' > projects/beta/methodologies/adr/README.org
# A responsibility is known by its configuration, not by the name of
# the directory holding it.
printf 'pos: 2\nprojects: projects/\n' > responsibilities/home/.clanka/config.yml
printf 'pos: 2\nprojects: projects/\n' > responsibilities/garden/.clanka/config.yml
printf '* NEXT Drafted\n' > drafts/d.org
printf '* Unsorted\n** NEXT Answer the letter\n' > intray.org
printf ':PROPERTIES:\n:STATUS:   COMMITTED\n:END:\n* NEXT Draft the outline\n* TODO Review Alpha :review:\nSCHEDULED: <%s>\n' \
    "$(day -1)" > projects/alpha/project.org
printf ':PROPERTIES:\n:STATUS:   WIP\n:END:\n* TODO Book the room\nSCHEDULED: <%s>\n* TODO File the return\nDEADLINE: <%s -3d>\n' \
    "$(day 5)" "$(day 40)" > projects/beta/project.org
printf '* TODO Review the home :review:\nSCHEDULED: <%s>\n' "$(day 0)" > responsibilities/home/index.org
printf '* TODO Prune the hedge\n' > responsibilities/garden/index.org
# The root's reviews, in a file of the root's own naming.
printf '* Reviews\n** TODO Weekly review :review:\nSCHEDULED: <%s ++1w>\n** TODO Monthly review :review:\nSCHEDULED: <%s ++4w>\n' \
    "$(day 2)" "$(day 23)" > life.org
printf '* NEXT Archived\n' > archives/old.org
printf '* NEXT Generated\n' > _tmp/scratch.org
# A responsibility and a project as responsibility-tree makes them.
"$bin/responsibility-tree" --responsibility health > /dev/null 2>&1
(cd health && "$bin/responsibility-tree" --project checkup > /dev/null 2>&1)
"$bin/pos-capture" -- 'Sort the shelf' > /dev/null 2>&1
(cd health && "$bin/pos-capture" -- 'Book the dentist' > /dev/null 2>&1)
find . -type f ! -name before | sort > before

"$bin/startup-prompt" > out 2>/dev/null
check "the prompts come first" test "$(head -1 out)" = "START-UP PROMPTS"
check "the files read are counted" grep -q '^Files read: 8$' out
check "next lists a NEXT item by its scope" grep -q '^  alpha  *NEXT Draft the outline$' out
check "an archive is not read" sh -c '! grep -q Archived out'
check "an underscore directory is not read" sh -c '! grep -q Generated out'
check "a directory the configuration excludes is not read" sh -c '! grep -q Drafted out'
check "a methodology's own file is not read" sh -c '! grep -q "Inside the methodology" out'
check "the kinds a methodology declares are listed, with where to start" \
    grep -q '^  projects/beta  *adr  *decision  *decisions/  *start at decisions/index.json$' out
check "and a derived kind with its own file as its entrance" \
    grep -q '^  projects/beta  *adr  *decision-index  *decisions/index.json  *start at decisions/index.json$' out
check "scheduled lists an item in the horizon" grep -q '^  beta  *Scheduled:  *TODO Book the room$' out
check "deadlines lists one beyond its warning" grep -q '^  beta  *Due in  40 days:  *TODO File the return$' out
check "a review scheduled yesterday is one day late" \
    grep -q '^  alpha  *1 days late:  *TODO Review Alpha$' out
check "a review scheduled today is not late" \
    grep -q '^  responsibilities/home/index  *Scheduled:  *TODO Review the home$' out
check "an active project with no review is named" grep -q '^  projects/beta  *WIP$' out
check "a project with a review is not" sh -c '! grep -q "^  projects/alpha " out'
check "a responsibility with no review is named" grep -q '^  responsibilities/garden$' out
check "the root's reviews are listed as the root's" \
    sh -c "grep -A2 '^Root reviews, late or due in the next 7 days\$' out | grep -q '^  life  *Scheduled:  *TODO Weekly review\$'"
check "a root review beyond the window is not" sh -c '! grep -q "Monthly review" out'
check "a root with a review is not named" \
    sh -c "grep -A1 '^Root with a review to be scheduled\$' out | grep -q '^  (none)\$'"
check "a responsibility is known by its configuration" grep -q '^  health$' out
check "a project made by responsibility-tree is named" grep -q '^  health/projects/checkup  *COMMITTED$' out
check "the intray lists what is captured, by its scope" \
    sh -c "grep -A3 '^Intray, to be placed\$' out | grep -q '^  health/intray  *TODO Book the dentist\$'"
check "and the root's" grep -q '^  intray  *TODO Sort the shelf$' out
check "every TODO item is not printed unasked" sh -c '! grep -q "^All TODO items" out'

"$bin/startup-prompt" --view all > all 2>/dev/null
check "--view all prints every open item" grep -q 'TODO Prune the hedge$' all
check "--view prints only the views named" sh -c '! grep -q "^NEXT items" all'

rm -f out all
check "nothing is written" sh -c 'find . -type f ! -name before | sort | diff - before'
check "an unknown view is usage" status 2 "$bin/startup-prompt" --view bogus

[ "$failures" -eq 0 ]
