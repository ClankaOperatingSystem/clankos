#!/usr/bin/env bash
# Run bin/pos-sweep against a new workspace.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

git init -q . && git config user.email t@example.org && git config user.name T
mkdir -p .pos projects/alpha
printf 'pos: 2\nprojects: projects/\narchives:\n  - scope: "."\n    kept: committed\n    sweep: sealed\n' > .pos/config.yaml
printf '#+TITLE: Intray\n\n* Unsorted\n** DONE Buy milk\n** TODO Water the plants\n* DONE Parent\n** TODO Still open\n' > intray.org
printf '#+TITLE: Alpha\n\n* DONE Draft the outline\n* NEXT Review it\n' > projects/alpha/project.org
git add -A && git commit -q -m "Begin"

"$bin/pos-sweep" plan > out 2>/dev/null
check "plan reports the files written" grep -q 'files with done entries written to sweep.org$' out
check "plan is titled with the week" grep -q '^#+TITLE: Sweep ' sweep.org
# The week the latest boundary closed, which the plan names.
week=$(sed -n 's/^#+TITLE: Sweep //p' sweep.org)
check "plan has a row for a file with done entries" grep -q '^| sweep *| intray.org *| *1 *| _sweep/' sweep.org
check "plan has a row for a nested project file" grep -q '^| sweep *| projects/alpha/project.org *| *1 *|' sweep.org
check "plan names a done entry with an open child" grep -q '^- intray.org: Parent$' sweep.org
check "plan changes no file" grep -q 'DONE Buy milk' intray.org

"$bin/pos-sweep" apply --dry-run > out 2>/dev/null
check "an apply dry run reports" grep -q '^Would sweep .*: archived 2, skipped 1' out
check "an apply dry run changes nothing" grep -q 'DONE Buy milk' intray.org
"$bin/pos-sweep" apply sweep.org --dry-run > out 2>/dev/null
check "a dry run is read after the plan's name" grep -q '^Would sweep .*: archived 2, skipped 1' out
check "and changes nothing" grep -q 'DONE Buy milk' intray.org
check "another option after apply is usage" status 2 "$bin/pos-sweep" apply sweep.org --dryrun
check "the plan carries a digest of each file's done entries" \
    grep -q '^| sweep *| intray.org *| *1 *| [^|]* *| [0-9a-f]\{12\} *|$' sweep.org

# The review: leave the project's file alone.
sed -i.bak 's/^| sweep *| projects/| skip | projects/' sweep.org && rm -f sweep.org.bak
"$bin/pos-sweep" apply > out 2>/dev/null
check "apply reports" grep -q '^Sweep .*: archived 1, skipped 1, 1 files left, 0 stale' out
check "apply moves the done entry out of the intray" sh -c '! grep -q "Buy milk" intray.org'
check "apply leaves the open entry" grep -q 'TODO Water the plants' intray.org
check "apply leaves a done entry with an open child" grep -q 'DONE Parent' intray.org
check "apply writes the week's archive file under _sweep" grep -q 'DONE Buy milk' "_sweep/$week/intray.org_archive"
check "apply stamps the week's boundary" grep -q ':ARCHIVE_TIME:' "_sweep/$week/intray.org_archive"
check "a file marked skip is left" grep -q 'DONE Draft the outline' projects/alpha/project.org

"$bin/pos-sweep" close > out 2>/dev/null
check "nothing has closed this week" test "$(cat out)" = "[]"
mkdir -p _sweep/2026-W01 && printf '* DONE Old\n' > _sweep/2026-W01/intray.org_archive
"$bin/pos-sweep" close > out 2>/dev/null
check "a week that has closed has a seal plan" grep -q '"destination":".*archives/sweep/2026-W01"' out
check "close changes nothing" test -d _sweep/2026-W01
"$bin/pos-sweep" close --apply > out 2>/dev/null
check "close --apply seals the week" grep -q '^sealed archive-integrity/' out
check "the sealed week is in the archive" test -f archives/sweep/2026-W01/intray.org_archive
check "the week is gone from _sweep" test ! -e _sweep/2026-W01
check "the archive checks clean" status 0 "$bin/archive-integrity" check .
check "an unknown command is usage" status 2 "$bin/pos-sweep" bogus

[ "$failures" -eq 0 ]
