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

mkdir sub
check "paths are relative to the working directory" \
    sh -c "cd sub && '$bin/archive-integrity' check ../archives >/dev/null"

check "checkpoint records the heads" status 0 "$bin/archive-integrity" checkpoint .

chmod u+w archives/2026-01-01-note.txt
echo "Changed." >> archives/2026-01-01-note.txt
check "check finds a changed item" status 1 "$bin/archive-integrity" check .

check "an unknown command is refused" status 2 "$bin/archive-integrity" bogus
check "clankos-run refuses a command the image lacks" status 127 "$bin/clankos-run" bogus
check "help needs no container" status 0 env CLANKOS_IMAGE=none.invalid/none "$bin/archive-integrity" --help

[ "$failures" -eq 0 ]
