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
    home/.clanka garden/.clanka shed/.clanka tools/widget archives _tmp drafts
# The root excludes a directory of its own besides the default ones, and
# declares beta, a project that is a directory with a configuration,
# and widget, a repository with none, which is a product.
printf 'pos: 2\nprojects: projects/\nexclude:\n  - archives\n  - attic\n  - node_modules\n  - "_*"\n  - ".*"\n  - drafts\nchildren:\n  - path: projects/beta\n  - path: tools/widget\n  - path: home\n  - path: garden\n  - path: shed\n' > .pos/config.yaml
git init -q tools/widget
printf '* NEXT Oil the widget\n' > tools/widget/notes.org
# beta uses a methodology, adr, which declares two kinds of canon and
# holds an Org file of its own, which is not beta's.
printf 'pos: 2\nmethodologies: methodologies\nchildren:\n  - path: methodologies/adr\n' > projects/beta/.clanka/config.yml
printf 'methodology: 1\ncanon:\n  - kind: decision\n    at: decisions/\n    format: markdown\n    entrance: decisions/index.json\n  - kind: decision-index\n    at: decisions/index.json\n    format: json\n    derived: true\n' \
    > projects/beta/methodologies/adr/methodology.yaml
printf '* NEXT Inside the methodology\n' > projects/beta/methodologies/adr/README.org
# A responsibility is known by its configuration, not by the name of
# the directory holding it, and is read because the root declares it.
# loft has a configuration and no declaration.
mkdir -p loft/.clanka
printf 'pos: 2\nprojects: projects/\n' > loft/.clanka/config.yml
printf '* NEXT Clear the loft\n' > loft/index.org
printf 'pos: 2\nprojects: projects/\n' > home/.clanka/config.yml
printf 'pos: 2\nprojects: projects/\n' > garden/.clanka/config.yml
# shed has no review of its own; home's review names it.
printf 'pos: 2\nprojects: projects/\n' > shed/.clanka/config.yml
printf '* NEXT Drafted\n' > drafts/d.org
printf '* Unsorted\n** NEXT Answer the letter\n' > intray.org
printf ':PROPERTIES:\n:STATUS:   COMMITTED\n:END:\n* NEXT Draft the outline\n* TODO Review Alpha :review:\nSCHEDULED: <%s>\n' \
    "$(day -1)" > projects/alpha/project.org
printf ':PROPERTIES:\n:STATUS:   WIP\n:END:\n* TODO Book the room\nSCHEDULED: <%s>\n* TODO File the return\nDEADLINE: <%s -3d>\n' \
    "$(day 5)" "$(day 40)" > projects/beta/project.org
printf '* TODO Review the home :review:\nSCHEDULED: <%s>\n:PROPERTIES:\n:COVERS:   ../shed\n:END:\n' "$(day 0)" > home/index.org
printf '* TODO Prune the hedge\n* WAITING Hear from the roofer\n* SOMEDAY Learn to weld\n* DONE Mow the lawn\nCLOSED: [%s]\n' \
    "$(day 0)" > garden/index.org
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
check "the files read are counted, a product's among them" grep -q '^Files read: 9$' out
check "next lists a NEXT item by its scope" grep -q '^  alpha  *NEXT Draft the outline$' out
check "next lists the items of projects under their own title" \
    sh -c "grep -A1 '^NEXT items of projects\$' out | grep -q '^  alpha  *NEXT Draft the outline\$'"
check "and says when responsibilities have none" \
    sh -c "grep -A1 '^NEXT items of responsibilities\$' out | grep -q '^  (none)\$'"
check "and the root's under theirs" \
    sh -c "grep -A1 '^NEXT items of the root\$' out | grep -q '^  intray  *NEXT Answer the letter\$'"
check "and a product's under theirs" \
    sh -c "grep -A1 '^NEXT items of products\$' out | grep -q '^  tools/widget/notes  *NEXT Oil the widget\$'"
check "waiting lists a WAITING item by its scope" \
    sh -c "grep -A1 '^WAITING items\$' out | grep -q '^  garden/index  *WAITING Hear from the roofer\$'"
check "someday is not printed unless named" sh -c '! grep -q "^SOMEDAY items" out'
check "an archive is not read" sh -c '! grep -q Archived out'
check "an underscore directory is not read" sh -c '! grep -q Generated out'
check "a directory the configuration excludes is not read" sh -c '! grep -q Drafted out'
check "a methodology's own file is not read" sh -c '! grep -q "Inside the methodology" out'
check "a configured directory nothing declares is not read" sh -c '! grep -q "Clear the loft" out'
check "and is named as not read" grep -q '^Not read: loft ' out
check "the kinds a methodology declares are listed, with where to start" \
    grep -q '^  projects/beta  *adr  *decision  *decisions/  *start at decisions/index.json$' out
check "and a derived kind with its own file as its entrance" \
    grep -q '^  projects/beta  *adr  *decision-index  *decisions/index.json  *start at decisions/index.json$' out
check "scheduled lists an item in the horizon" grep -q '^  beta  *Scheduled:  *TODO Book the room$' out
check "deadlines lists one beyond its warning" grep -q '^  beta  *Due in  40 days:  *TODO File the return$' out
check "a review scheduled yesterday is one day late" \
    grep -q '^  alpha  *1 days late:  *TODO Review Alpha$' out
check "a review scheduled today is not late" \
    grep -q '^  home/index  *Scheduled:  *TODO Review the home$' out
check "an active project with no review is named" grep -q '^  projects/beta  *WIP$' out
check "a project with a review is not" sh -c '! grep -q "^  projects/alpha " out'
check "a responsibility with no review is named" grep -q '^  garden$' out
check "a responsibility a review elsewhere names is not" sh -c '! grep -q "^  shed$" out'
check "a begun project with no next action is stuck" \
    sh -c "grep -A1 '^Projects with no next action\$' out | grep -q '^  projects/beta  *WIP\$'"
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
"$bin/startup-prompt" --view someday > someday 2>/dev/null
check "--view someday lists a SOMEDAY item by its scope" \
    sh -c "grep -A1 '^SOMEDAY items\$' someday | grep -q '^  garden/index  *SOMEDAY Learn to weld\$'"
"$bin/startup-prompt" --view projects > projects.out 2>/dev/null
check "--view projects gives an active project its status and next review" \
    grep -q "^  projects/alpha  *COMMITTED  *review $(day -1)\$" projects.out
check "and its next action" \
    sh -c "grep -A1 '^  projects/alpha ' projects.out | grep -q '^    next: Draft the outline\$'"
"$bin/startup-prompt" --view finished > finished 2>/dev/null
check "--view finished lists what was closed in the week" \
    grep -q "^  garden/index  *$(day 0) DONE Mow the lawn\$" finished
"$bin/startup-prompt" --weekly > weekly 2>/dev/null
check "--weekly prints the views of a weekly review, the intray first" \
    test "$(grep -n -e '^Intray, to be placed$' -e '^NEXT items of projects$' -e '^SOMEDAY items$' \
              -e '^Finished in the last 7 days$' weekly | cut -d: -f2 | tr '\n' '|')" \
       = 'Intray, to be placed|NEXT items of projects|SOMEDAY items|Finished in the last 7 days|'
"$bin/startup-prompt" --json --view stuck > json 2>/dev/null
check "--json prints one line" test "$(wc -l < json | tr -d ' ')" = 1
check "with the count of files" grep -q '^{"files_read":9,' json
check "what was not read" grep -q '"not_read":\[{"path":"loft",' json
check "and each view named" \
    grep -q '"views":{"stuck":\[{"scope":"projects/beta","scope_kind":"project","status":"WIP"}\]}}$' json
check "an unknown view is usage" status 2 "$bin/startup-prompt" --view bogus

[ "$failures" -eq 0 ]
