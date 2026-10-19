#!/usr/bin/env bash
# Run bin/archive-integrity relocate-plan and relocate-apply against a
# garden whose archives lie beside its files, as earlier gardens kept
# them: the root's, committed, and that of a project with no
# configuration directory, kept uncommitted and ignored by Git.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.org
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.org

# listing: every file and directory of the garden but Git's, with its
# permissions.
listing() { find . -path ./.git -prune -o -print | sort | while IFS= read -r path; do
    printf '%s %s\n' "$(ls -ld "$path" | cut -c1-10)" "$path"; done; }
# events DIR: the SHA-256 of the ledger events in DIR, in order.
events() { cat "$1"/ledger/* > "$work/_events" && sha256 "$work/_events"; }

mkdir -p garden/.clanka garden/projects/study && cd garden || exit 1
git init -q -b master
printf 'pos: 2\nprojects: projects/\narchives:\n  - scope: "."\n    kept: committed\n' > .clanka/config.yml
printf '#+TITLE: Intray\n\n* Unsorted\n' > intray.org
printf '#+TITLE: Study\n' > projects/study/notes.org

# The archives are sealed where this image seals them, and then moved
# beside the files, where earlier images sealed them. Neither a ledger
# event nor a checkpoint names where its archive lies.
echo "The root's record." | "$bin/archive-integrity" write-new .clanka/archives/2026-01-01-root.txt --apply > /dev/null 2>&1
(cd projects/study && echo "The study's record." \
    | "$bin/archive-integrity" write-new .clankos/archives/2026-01-02-study.txt --apply > /dev/null 2>&1)
"$bin/archive-integrity" checkpoint . > /dev/null 2>&1
mv .clanka/archives archives
mv .clanka/archive-integrity archive-integrity
mv projects/study/.clankos/archives projects/study/archives
mv projects/study/.clankos/archive-integrity projects/study/archive-integrity
rmdir projects/study/.clankos
"$bin/responsibility-tree" --no-clone < /dev/null > /dev/null 2>&1
check "the earlier layout checks clean" status 0 "$bin/archive-integrity" check .
check "the project's archive is ignored beside its files" git check-ignore -q projects/study/archives/2026-01-02-study.txt
git add -A && git commit -qm 'Keep the garden'
check "and its ledger is committed" test -n "$(git ls-files projects/study/archive-integrity)"
root_events=$(events archive-integrity)
study_events=$(events projects/study/archive-integrity)
echo "Refused." | "$bin/archive-integrity" write-new archives/2026-01-03-refused.txt --apply > ../out 2>&1
refused=$?
check "a seal is refused until the archive is moved" sh -c "[ $refused -eq 2 ] && grep -q relocation-required ../out"

listing > ../before
"$bin/archive-integrity" relocate-plan . > ../plan 2>&1
check "relocate-plan exits 0" test $? -eq 0
check "it names the root's archive" grep -q 'archive-integrity' ../plan
check "and the project's" grep -q 'projects/study' ../plan
listing | diff -q - ../before > /dev/null
check "relocate-plan writes nothing" test $? -eq 0

"$bin/archive-integrity" relocate-apply . > ../out 2>&1
check "relocate-apply exits 0" test $? -eq 0
check "the root's archive is in .clanka" test -f .clanka/archives/2026-01-01-root.txt
check "with its ledger and checkpoints" \
    sh -c 'test -d .clanka/archive-integrity/ledger && test -n "$(ls .clanka/archive-integrity/checkpoints)"'
check "the project's archive is in a new .clankos" test -f projects/study/.clankos/archives/2026-01-02-study.txt
check "with its ledger" test -d projects/study/.clankos/archive-integrity/ledger
check "and no configuration file there" sh -c '! ls projects/study/.clankos/config.* 2>/dev/null'
check "nothing is left beside the files" \
    sh -c '! ls -d archives archive-integrity projects/study/archives projects/study/archive-integrity 2>/dev/null'
check "no ledger event is changed" \
    test "$(events .clanka/archive-integrity) $(events projects/study/.clankos/archive-integrity)" = "$root_events $study_events"
check "a sealed file keeps its bytes" grep -qx "The root's record." .clanka/archives/2026-01-01-root.txt
check "and has no write bits" test ! -w .clanka/archives/2026-01-01-root.txt
check "the moved archives check clean" status 0 "$bin/archive-integrity" check .
check "Git sees renames only" test -z "$(git status --porcelain | grep -v '^R  ')"
check "and some" test -n "$(git status --porcelain)"
check "the uncommitted archive is ignored at its new place" \
    git check-ignore -q projects/study/.clankos/archives/2026-01-02-study.txt
check "and its old exclusion is gone" sh -c '! git check-ignore -q projects/study/archives/evidence'
check "nothing is committed" test "$(git rev-list --count HEAD)" = 1

git commit -qm 'Move archives into the configuration directory'
listing > ../before
"$bin/archive-integrity" relocate-apply . > ../out 2>&1
check "relocate-apply run again exits 0" test $? -eq 0
listing | diff -q - ../before > /dev/null
check "and changes nothing" test $? -eq 0
check "nor anything Git sees" test -z "$(git status --porcelain)"

echo "After." | "$bin/archive-integrity" write-new archives/2026-01-03-after.txt --apply > /dev/null 2>&1
check "a fresh seal writes into .clanka" test -f .clanka/archives/2026-01-03-after.txt
(cd projects/study && echo "After." \
    | "$bin/archive-integrity" write-new archives/2026-01-04-after.txt --apply > /dev/null 2>&1)
check "and a project's into its .clankos" test -f projects/study/.clankos/archives/2026-01-04-after.txt
check "making nothing beside the files" sh -c '! ls -d archives projects/study/archives 2>/dev/null'
check "a checkpoint is written in .clanka" status 0 "$bin/archive-integrity" checkpoint .
check "and the garden checks clean" status 0 "$bin/archive-integrity" check .

[ "$failures" -eq 0 ]
