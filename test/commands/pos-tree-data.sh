#!/usr/bin/env bash
# Run bin/pos-tree-data against a new workspace.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"

# The root has an image, a one-file project, a responsibility with a
# project of its own, and widget, a repository with no configuration,
# which is a product on a branch of its own. Its main file holds an ID
# and a body that is not ASCII.
mkdir -p .pos projects home/.clanka home/projects/roof tools/widget
printf 'pos: 2\nimage: example.org/image:1\nprojects: projects/\nchildren:\n  - path: home\n  - path: tools/widget\n    remote: https://example.org/widget.git\n    branch: main\n' > .pos/config.yaml
printf ':PROPERTIES:\n:ID:       root-id\n:END:\n#+TITLE: Root\n\n* NEXT Water the plants\nOne · two — three é\n' > index.org
printf ':PROPERTIES:\n:STATUS:   WIP\n:OUTCOME:  The roof is fixed.\n:END:\n#+TITLE: Alpha\n* NEXT Draft the outline\n' > projects/alpha.org
printf 'pos: 2\nprojects: projects/\n' > home/.clanka/config.yml
printf '#+TITLE: Home\n' > home/index.org
printf '#+TITLE: Roof\n* NEXT Call the roofer\n' > home/projects/roof/project.org
git init -q tools/widget
printf '* TODO Oil the widget\n' > tools/widget/notes.org
find . -type f ! -path '*/.git/*' | sort > ../before

"$bin/pos-tree-data" > json 2> ../err
status=$?
check "pos-tree-data exits 0" test "$status" -eq 0
check "it prints one line" test "$(wc -l < json | tr -d ' ')" = 1
check "of the document's version first" grep -q '^{"version":1,"made":"' json
check "the root is the first scope, with its title, file and ID" \
    grep -q '"scopes":\[{"path":".","kind":"root","title":"Root","file":"index.org","id":"root-id","parent":null,' json
check "the root's image is its own" grep -q '"image":"example.org/image:1","image_from":"."' json
check "a one-file project has its status and outcome" \
    grep -q '"path":"projects/alpha","kind":"project","title":"Alpha","file":"projects/alpha.org",[^}]*"status":"WIP","outcome":"The roof is fixed."' json
check "a responsibility's project lies beneath it" \
    grep -q '"path":"home/projects/roof","kind":"project","title":"Roof","file":"home/projects/roof/project.org","id":null,"parent":"home",' json
check "the product has no configuration" \
    grep -q '"path":"tools/widget","kind":"product",[^}]*"configuration":null,' json
check "its repository has the remote and branch declared" \
    grep -q '{"path":"tools/widget","remote":"https://example.org/widget.git","branch":"main","installed":null}' json
check "each ID has its file, line and scope" \
    grep -q '"ids":{"root-id":{"file":"index.org","line":1,"scope":"."}}' json
check "every start-up view is given" \
    sh -c "grep -o '\"views\":{\"handover\":.*\"all\":' json > /dev/null"
check "a body that is not ASCII is its UTF-8 bytes" grep -q 'One · two — three é' json

"$bin/pos-tree-data" --view next > json 2>/dev/null
check "--view gives that view" grep -q '"views":{"next":\[.*\]}}$' json
check "and no other" sh -c "! grep -q '\"waiting\":\[' json"
rm json

check "an unknown view is usage" status 2 "$bin/pos-tree-data" --view bogus
find . -type f ! -path '*/.git/*' | sort > ../after
check "nothing is written" cmp -s ../before ../after

[ "$failures" -eq 0 ]
