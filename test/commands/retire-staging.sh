#!/usr/bin/env bash
# A retired project's archive root survives Git dropping empty
# directories, and a project whose archive lies in its .clankos/ is
# retired with its archive and ledger at their visible places.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"

# The root's archive is in .pos/, its one configuration directory.
archive=.pos/archives
mkdir -p .pos trial/_seal trial/archives/old/_seal trial/ordinary
echo "Result." > trial/result.txt
chmod 600 trial/result.txt
echo "Recorded." > trial/archives/old/record.txt
check "retire the project" status 0 "$bin/archive-integrity" seal trial $archive/trial --apply
check "empty staging is not archived" test ! -e $archive/trial/_seal
check "nested archived staging is preserved" test -d $archive/trial/archives/old/_seal
check "ordinary empty directory is preserved" test -d $archive/trial/ordinary
check "archive is clean before cloning" status 0 "$bin/archive-integrity" check .

# A project with no configuration keeps its archive in .clankos/.
mkdir study
echo "Observed." > study/notes.txt
(cd study && echo "Measured." | "$bin/archive-integrity" write-new .clankos/archives/old/record.txt --apply >/dev/null 2>&1)
check "the project's archive is in its .clankos" test -f study/.clankos/archives/old/record.txt
# events DIR: the SHA-256 of the ledger events in DIR, in order.
events() { cat "$1"/ledger/* > "$work/_events" && sha256 "$work/_events"; }
before=$(events study/.clankos/archive-integrity)
check "retire the project with a hidden archive" status 0 "$bin/archive-integrity" seal study $archive/study --apply
check "its archive is sealed at its visible place" \
    test "$(cat $archive/study/archives/old/record.txt)" = "Measured."
check "its ledger is sealed at its visible place" test "$(events $archive/study/archive-integrity)" = "$before"
check "the hidden directory is not sealed" test ! -e $archive/study/.clankos
check "the project's own files are sealed" test -f $archive/study/notes.txt
check "the project is gone from the tree" test ! -e study
check "archive is clean after the retirement" status 0 "$bin/archive-integrity" check .

git init -q
git add .pos/archives .pos/archive-integrity
git -c user.name=Test -c user.email=test@example.org -c commit.gpgsign=false \
    commit -qm "Keep the archive"
git clone -q --no-local . clone
cd clone || exit 1
check "clone lost the recorded empty directories" test ! -e $archive/trial/archives/old/_seal
check "restore directories and read-only permissions" status 0 "$bin/archive-integrity" repair .
check "archive is clean after cloning" status 0 "$bin/archive-integrity" check .
check "ledger and checkpoints are unchanged" test -z "$(git status --porcelain -- .pos/archive-integrity)"

[ "$failures" -eq 0 ]
