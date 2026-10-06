#!/usr/bin/env bash
# A retired project's archive root survives Git dropping empty directories.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

mkdir -p .pos trial/_seal trial/archives/old/_seal trial/ordinary
echo "Result." > trial/result.txt
chmod 600 trial/result.txt
echo "Recorded." > trial/archives/old/record.txt
check "retire the project" status 0 "$bin/archive-integrity" seal trial archives/trial --apply
check "empty staging is not archived" test ! -e archives/trial/_seal
check "nested archived staging is preserved" test -d archives/trial/archives/old/_seal
check "ordinary empty directory is preserved" test -d archives/trial/ordinary
check "archive is clean before cloning" status 0 "$bin/archive-integrity" check .

git init -q
git add archives archive-integrity
git -c user.name=Test -c user.email=test@example.org -c commit.gpgsign=false \
    commit -qm "Keep the archive"
git clone -q --no-local . clone
cd clone || exit 1
check "clone lost the recorded empty directories" test ! -e archives/trial/archives/old/_seal
check "restore directories and read-only permissions" status 0 "$bin/archive-integrity" repair .
check "archive is clean after cloning" status 0 "$bin/archive-integrity" check .
check "ledger and checkpoints are unchanged" test -z "$(git status --porcelain -- archive-integrity)"

[ "$failures" -eq 0 ]
