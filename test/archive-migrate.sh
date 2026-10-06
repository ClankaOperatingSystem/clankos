#!/usr/bin/env bash
# Run bin/archive-migrate against a copy of the legacy archive in
# test/fixtures/archive-migrate: one record, enrolled in a schema 1
# ledger inside the archive, linking to a file outside it. The fixture
# names the archive legacy, so that an integrity check of a tree
# holding this repository does not take the fixture for an archive.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

mkdir .pos
cp -R "$repo/test/fixtures/archive-migrate/." .
mv legacy archives

"$bin/archive-migrate" plan archives . > plan.json 2>/dev/null
check "plan prints a plan" grep -q '"operation":"migrate"' plan.json
check "plan leaves the archive as it was" test -d archives/.archive-integrity
check "plan plans a rumour for the link out of the archive" grep -q 'Rumour of plan.org' plan.json

check "a plan under another hash is refused" status 2 "$bin/archive-migrate" apply plan.json 0000
"$bin/archive-migrate" apply plan.json "$(sha256 plan.json)" >/dev/null 2>&1
check "apply moves the ledger beside the archive" test ! -e archives/.archive-integrity
check "apply adds the conversion event" test "$(ls archive-integrity/ledger | wc -l | tr -d ' ')" = 2
check "apply checkpoints the head" test -n "$(ls archive-integrity/checkpoints 2>/dev/null)"
check "apply rewrites the link as an ipfs link" grep -q '](ipfs://' archives/2026-01-01-first.md
check "apply seals the rumour" test -n "$(ls archives/rumours 2>/dev/null)"
check "the migrated archive is the invoking user's" test "$(owner archives/2026-01-01-first.md)" = "$(id -u)"
check "the migrated archive checks clean" status 0 "$bin/archive-integrity" check archives

check "no arguments is usage" status 2 "$bin/clankos-run" archive-migrate

[ "$failures" -eq 0 ]
