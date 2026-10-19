#!/usr/bin/env bash
# Run bin/pos-org-html against a new workspace.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"

# The root's file links to a heading in home's file, to an ID there and
# to a web page, holds a body that is not ASCII, and a source block that
# would write a file if it were evaluated.
mkdir -p .pos home
printf 'pos: 2\n' > .pos/config.yaml
printf '%s\n' '#+TITLE: Root' '* Tasks' \
    '- [[file:home/index.org::*The hall][the hall]]' \
    '- [[id:roof-id][the roof]]' \
    '- [[https://example.org/][a site]]' \
    'One · two — three é' \
    '#+begin_src emacs-lisp :exports results' \
    '(write-region "" nil "evaluated")' \
    '#+end_src' > index.org
printf '%s\n' '* The hall' '* The roof' ':PROPERTIES:' ':ID:       roof-id' ':END:' > home/index.org
find . -type f ! -path '*/.git/*' | sort > ../before

"$bin/pos-org-html" index.org home/index.org missing.org > json 2> ../err
status=$?
check "pos-org-html exits 0" test "$status" -eq 0
check "it prints one line" test "$(wc -l < json | tr -d ' ')" = 1
check "each file in order, the first with its title" \
    grep -q '^\[{"file":"index.org","title":"Root","html":".*},{"file":"home/index.org","title":null,"html":".*},{"file":"missing.org","error":"' json
check "a link to a heading in another file leads to its page and anchor" \
    grep -qF '<a href=\"/file/home/index.org#the-hall\">the hall</a>' json
check "an id: link leads to the ID's address" grep -qF '<a href=\"/id/roof-id\">the roof</a>' json
check "a web link is itself" grep -qF '<a href=\"https://example.org/\">a site</a>' json
check "a heading with an ID has both anchors" grep -qF '<h2 id=\"the-roof\"><a id=\"roof-id\"></a>' json
check "a body that is not ASCII is its UTF-8 bytes" grep -q 'One · two — three é' json

"$bin/pos-org-html" --file-url '/garden/%s.html' --id-url '/ids/%s' index.org > json 2>/dev/null
check "--file-url sets a page's address" grep -qF 'href=\"/garden/home/index.org.html#the-hall\"' json
check "--id-url sets an ID's address" grep -qF 'href=\"/ids/roof-id\"' json
rm json

check "no file is usage" status 2 "$bin/pos-org-html"
find . -type f ! -path '*/.git/*' | sort > ../after
check "nothing is written or evaluated" cmp -s ../before ../after

[ "$failures" -eq 0 ]
