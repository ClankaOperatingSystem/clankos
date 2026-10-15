#!/usr/bin/env bash
# Run bin/session-facts against a new workspace with commits and seals.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.org
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.org

git init -q -b master
mkdir .pos
printf 'pos: 2\nprojects: projects/\n' > .pos/config.yaml
printf '#+TITLE: Intray\n\n* Unsorted\n' > intray.org
git add . && git commit -qm 'Begin'
since=$(git rev-parse HEAD)
printf 'First.\n' | "$bin/wrap-up" -- 'The first session' > /dev/null 2>&1
git add . && git commit -qm 'Publish the first handover'
"$bin/pos-capture" -- 'Sort the shelf' > /dev/null 2>&1
printf 'Second.\n' | "$bin/wrap-up" -- 'The second session' > /dev/null 2>&1
find . -type f ! -path './.git/*' | sort > ../before

"$bin/session-facts" "$since" > ../out 2> ../err
status=$?
check "session-facts exits 0" test "$status" -eq 0
check "and says nothing on stderr but that the image's skills are not installed" \
    sh -c "! grep -v -e '^clankos: lock-differs .*: not installed)\$' -e '^clankos: each is a skills-lock.json' ../err"
check "it names the commit it starts from" grep -q '^Commits after [0-9a-f]* Begin$' ../out
check "and lists the commit after it" grep -q '^  [0-9a-f]* Publish the first handover$' ../out
check "with no upstream, pushed is not known" grep -q '^  HEAD has no upstream' ../out
check "the committed event is listed" \
    grep -Eq '^  \. event 1: journal/[0-9-]+-the-first-session\.org \(committed\)$' ../out
check "and the uncommitted one" \
    grep -Eq '^  \. event 2: journal/[0-9-]+-the-second-session\.org \(not committed\)$' ../out
check "nothing is written" sh -c "find . -type f ! -path './.git/*' | sort | diff - ../before"

"$bin/session-facts" HEAD > ../head 2>/dev/null
check "a commit with no commit after it says none" \
    sh -c "grep -A1 '^Commits after' ../head | grep -q '^  (none)\$'"
check "and lists the event it does not have" grep -q '^  \. event 2:' ../head
check "a name that is no commit is usage" status 2 "$bin/session-facts" nothing-of-the-kind
check "no commit named is usage" status 2 "$bin/session-facts"
check "--help prints the usage" sh -c "'$bin/session-facts' --help | grep -q '^Usage: session-facts'"

[ "$failures" -eq 0 ]
