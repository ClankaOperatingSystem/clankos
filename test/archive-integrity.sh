#!/usr/bin/env bash
# Run bin/archive-integrity against a new workspace.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

mkdir _seal .pos
echo "A note." > _seal/note.txt

"$bin/archive-integrity" seal _seal/note.txt archives/2026-01-01-note.txt > plan.json
check "seal prints a plan" grep -q '"operation":"seal"' plan.json
check "a plan changes nothing" test ! -e archives

mv plan.json _seal/plan.json
"$bin/archive-integrity" apply _seal/plan.json "$(sha256 _seal/plan.json)" > applied.json
check "apply seals the item" test -f archives/2026-01-01-note.txt
check "the sealed item is read-only" test ! -w archives/2026-01-01-note.txt
check "the sealed item is the invoking user's" test "$(owner archives/2026-01-01-note.txt)" = "$(id -u)"
check "apply writes a ledger event" test -n "$(ls archive-integrity/ledger 2>/dev/null)"
check "a plan under another hash is refused" status 2 "$bin/archive-integrity" apply _seal/plan.json 0000
rm -f applied.json

check "check is clean" status 0 "$bin/archive-integrity" check .

echo "Second." | "$bin/archive-integrity" write-new archives/2026-01-02-second.txt --apply >/dev/null
check "write-new seals standard input" grep -q Second. archives/2026-01-02-second.txt

link=$("$bin/archive-integrity" link archives/2026-01-02-second.txt)
"$bin/archive-integrity" search . Second > found 2> err
check "search prints each hit as LINK:LINE:TEXT" test "$(cat found)" = "$link:1:Second."
check "search with a regex is grep -E's" \
    sh -c "'$bin/archive-integrity' search . '^(A|Second)' --mode regex | grep -c . | grep -qx 2"
check "search within one item sees that item alone" \
    sh -c "'$bin/archive-integrity' search . note --within '${link#ipfs://}' >/dev/null; [ \$? -eq 1 ]"
check "a search that finds nothing exits 1" status 1 "$bin/archive-integrity" search . nothing-of-the-kind
check "a search in a mode the image lacks is refused" status 2 "$bin/archive-integrity" search . Second --mode words

mkdir trial
printf ':PROPERTIES:\n:ID: trial-notes\n:END:\n* Result\n' > trial/notes.org
printf 'See [[file:trial/notes.org::*Result][the result]] and [[id:trial-notes][the notes]].\n' > index.org
"$bin/archive-integrity" links-into . trial > found 2> err
check "links-into prints each link into a path, by file and by ID" \
    test "$(sort found)" = "index.org:1: file:trial/notes.org::*Result -> trial/notes.org
index.org:1: id:trial-notes -> trial/notes.org"
"$bin/archive-integrity" seal trial archives/2026-01-03-trial > _seal/trial.json
"$bin/archive-integrity" relink . _seal/trial.json > _seal/relink.json 2> err
check "relink prints a plan of the links to the item" \
    sh -c "grep -q '\"operation\":\"relink\"' _seal/relink.json && grep -q '\"file\":\"index.org\"' _seal/relink.json"
check "a relink plan is refused before its seal is applied" \
    status 2 "$bin/archive-integrity" apply _seal/relink.json "$(sha256 _seal/relink.json)"
"$bin/archive-integrity" apply _seal/trial.json "$(sha256 _seal/trial.json)" >/dev/null 2>&1
"$bin/archive-integrity" apply _seal/relink.json "$(sha256 _seal/relink.json)" > applied.json 2> err
check "applied after the seal, it reports the files rewritten" grep -q '"rewritten":\["index.org"\]' applied.json
item=$("$bin/archive-integrity" link archives/2026-01-03-trial)
check "and each link cites the sealed item" \
    test "$(cat index.org)" = "See [[$item/notes.org::*Result][the result]] and [[$item/notes.org][the notes]]."
rm -f applied.json found index.org

mkdir sub
check "paths are relative to the working directory" \
    sh -c "cd sub && '$bin/archive-integrity' check ../archives >/dev/null"

check "checkpoint records the heads" status 0 "$bin/archive-integrity" checkpoint .

# Retiring a document: its open task is salvaged, and after the seal
# and the relink the copy cites the sealed item.
mkdir attic
printf '* Unsorted\n' > intray.org
printf '* Thinking\n** TODO Call the plumber\n** DONE Paint\n' > attic/note.org
"$bin/archive-integrity" salvage . attic --dry-run > out 2> err
check "a salvage dry run names the open task" grep -qx 'attic/note.org:2: TODO Call the plumber' out
check "and writes nothing" grep -q '^\*\* TODO Call the plumber$' attic/note.org
"$bin/archive-integrity" salvage . attic > out 2> err
check "salvage copies the task to the intray" grep -q '^\*\* TODO Call the plumber$' intray.org
check "the copy has an ID" grep -Eq '^:ID: +[0-9A-Fa-f-]{36}$' intray.org
check "the copy cites where it stood" \
    grep -qF 'Salvaged from [[file:attic/note.org::*Call the plumber][attic/note.org]]' intray.org
check "the original is closed where it stood" grep -q '^\*\* CANCELLED Call the plumber$' attic/note.org
check "and cites the copy by its ID" grep -q '^Salvaged to the intray: \[\[id:' attic/note.org
check "a done task is left alone" grep -q '^\*\* DONE Paint$' attic/note.org
check "a source outside the root is refused" status 2 "$bin/archive-integrity" salvage . /nowhere

"$bin/archive-integrity" links-into . attic > out 2> err
check "links-into lists the copy's link" grep -q '^intray.org:[0-9]*: file:attic/note.org::\*Call the plumber -> attic/note.org$' out
"$bin/archive-integrity" seal attic archives/2026-01-03-attic > _seal/attic.json
"$bin/archive-integrity" relink . _seal/attic.json > _seal/attic-relink.json
check "relink prints a plan" grep -q '"operation":"relink"' _seal/attic-relink.json
"$bin/archive-integrity" apply _seal/attic.json "$(sha256 _seal/attic.json)" > /dev/null
"$bin/archive-integrity" apply _seal/attic-relink.json "$(sha256 _seal/attic-relink.json)" > out 2> err
check "applying the relink names the files rewritten" grep -q '"rewritten":\["intray.org"\]' out
item=$("$bin/archive-integrity" link archives/2026-01-03-attic)
check "the copy cites the sealed item" \
    grep -qF "Salvaged from [[$item/note.org::*Call the plumber][attic/note.org]]" intray.org
check "check is clean after the retirement" status 0 "$bin/archive-integrity" check .

chmod u+w archives/2026-01-01-note.txt
echo "Changed." >> archives/2026-01-01-note.txt
check "check finds a changed item" status 1 "$bin/archive-integrity" check .

# The workspace's configuration, as poslib's doc/pos-directory.txt has it.
chmod u-w archives/2026-01-01-note.txt
rmdir .pos
mkdir .clanka
printf 'pos: 2\nprojects: projects/\n' > .clanka/config.yml
check "a version 2 configuration in .clanka is read" status 1 "$bin/archive-integrity" check .
mv .clanka .clankos
check "a configuration in .clankos is read" status 1 "$bin/archive-integrity" check .
mv .clankos .clanka
printf 'pos: 1\n' > .clanka/config.yml
check "a version 1 configuration is refused" status 2 "$bin/archive-integrity" check .
printf 'pos: 2\nprojects: projects/\n' > .clanka/config.yml

check "an unknown command is refused" status 2 "$bin/archive-integrity" bogus
check "clankos-run refuses a command the image lacks" status 127 "$bin/clankos-run" bogus
check "help needs no container" status 0 env CLANKOS_IMAGE=none.invalid/none "$bin/archive-integrity" --help

[ "$failures" -eq 0 ]
