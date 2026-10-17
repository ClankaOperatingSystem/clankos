#!/usr/bin/env bash
# Run bin/pos-lint against a new workspace.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"

git init -q . && git config user.email t@example.org && git config user.name T
mkdir -p .pos projects/p/.clanka projects/p/methodologies/adr/skills/adr-write/scripts
printf 'pos: 2\nprojects: projects/\nchildren:\n  - path: projects/p\n' > .pos/config.yaml
printf ':PROPERTIES:\n:ID: intray\n:END:\n#+TITLE: Intray\n\n* Unsorted\n** TODO Water the plants\n' > intray.org
# A project that is a directory, with a methodology whose check finds
# one thing and prints one line that is not a finding.
printf 'pos: 2\nmethodologies: methodologies\nchildren:\n  - path: methodologies/adr\n' > projects/p/.clanka/config.yml
printf -- '---\nname: adr-write\ndescription: Write a decision.\n---\n' > projects/p/methodologies/adr/skills/adr-write/SKILL.md
printf '#!/bin/sh\necho "decisions/0002.md:3: status not known"\necho "index out of date"\nexit 1\n' > projects/p/methodologies/adr/skills/adr-write/scripts/check-status
chmod +x projects/p/methodologies/adr/skills/adr-write/scripts/check-status
printf '* NEXT Inside the methodology\n' > projects/p/methodologies/adr/README.org
git add -A && git commit -q -m "Begin"
# What the image installs is made before the first command, and what
# refresh keeps of it by the second; the lint itself writes nothing.
"$bin/clankos-run" refresh > out 2> err
"$bin/clankos-run" refresh > out 2> err
find . -type f ! -name before ! -name out ! -name err | sort > before

"$bin/pos-lint" > out 2> err
check "findings exit 1" test $? -eq 1
check "a check's finding is reported relative to the root" \
    grep -qx 'projects/p/decisions/0002.md:3: status not known' out
check "a line that is not a finding is one at the project" grep -qx 'projects/p:1: index out of date' out
check "the methodology's own file is not linted" sh -c '! grep -q methodologies/adr/README out'
check "nothing is written" sh -c 'find . -type f ! -name before ! -name out ! -name err | sort | diff - before'

printf '* DONE Parent\n** TODO Child\n' > projects/p/project.org
"$bin/pos-lint" > out 2> err
check "a done entry with an open child is reported" grep -qx 'projects/p/project.org:1: done entry has open children' out
check "a file with no file ID is reported" grep -qx 'projects/p/project.org:1: no file-level ID' out

printf '** NEXT Call the plumber\n** WAITING Hear back\n' >> intray.org
"$bin/pos-lint" > out 2> err
check "an intray item that is not TODO is reported" \
    grep -qx 'intray.org:8: NEXT item in the intray: clarified, to be placed' out
check "a WAITING item that says neither who nor since when is reported" \
    grep -qx 'intray.org:9: WAITING item does not say who or what it waits on, or since when' out
git checkout -q intray.org

rm -f projects/p/project.org projects/p/methodologies/adr/skills/adr-write/scripts/check-status
"$bin/pos-lint" > out 2> err
check "a clean tree exits 0" test $? -eq 0
check "and prints nothing" test ! -s out

check "an argument is usage" status 2 "$bin/pos-lint" bogus
check "--help names the document" sh -c "'$bin/pos-lint' --help | grep -qF 'clankos-run help pos-lint'"

[ "$failures" -eq 0 ]
