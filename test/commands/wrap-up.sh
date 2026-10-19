#!/usr/bin/env bash
# Run bin/wrap-up against a new workspace, and read the handover back
# through bin/startup-prompt and bin/archive-integrity.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"

mkdir .pos
printf 'pos: 2\nprojects: projects/\n' > .pos/config.yaml
today=$(date +%Y-%m-%d)

printf 'What happened.\n' | "$bin/wrap-up" -- 'The roof mended' > out 2> err
status=$?
check "wrap-up exits 0" test "$status" -eq 0
check "it prints the citation, the title and the date" \
    grep -Eq "^ipfs://bafk[a-z2-7]+: The roof mended, $today\$" out
citation=$(sed 's/: .*//' out)
check "the record is sealed in the configuration directory's archive, as given" \
    test "$(cat ".pos/archives/journal/$today-the-roof-mended.org")" = "What happened."
check "with a ledger beside the archive" test -d .pos/archive-integrity/ledger
check "the citation reads the record back" \
    test "$("$bin/archive-integrity" fetch "$citation" 2>/dev/null)" = "What happened."
check "the archive checks clean" "$bin/archive-integrity" check . > /dev/null 2>&1
check "the journal is made" test -f journal.org
check "its heading is tagged handover and latest" \
    grep -Eq '^\* The roof mended +:handover:latest:$' journal.org
check "with an ID" grep -Eq '^:ID: +[0-9a-f-]{36}$' journal.org
check "its date" grep -Eq "^:DATE: +\[$today [A-Z][a-z]{2}\]\$" journal.org
check "and the record's citation" grep -Eq "^:RECORD: +$citation\$" journal.org
check "the handover view names it" \
    sh -c "'$bin/startup-prompt' --view handover 2>/dev/null | grep -q '^  journal  *$today The roof mended $citation\$'"
check "the journal is the invoking user's" test "$(owner journal.org)" = "$(id -u)"
check "nothing is left staged" test ! -e _seal

printf 'Second.\n' | "$bin/wrap-up" --date 2030-03-04 -- 'The gutter cleared' > out2 2>/dev/null
check "--date dates the handover" grep -q '^ipfs://.*: The gutter cleared, 2030-03-04$' out2
check "and names its record" test -f .pos/archives/journal/2030-03-04-the-gutter-cleared.org
check "the new handover leads the journal as the latest" \
    sh -c "grep '^\* ' journal.org | head -n 1 | grep -Eq '^\* The gutter cleared +:handover:latest:\$'"
check "the earlier one keeps its handover tag alone" \
    grep -Eq '^\* The roof mended +:handover:$' journal.org
check "the handover view names the latest alone" \
    test "$("$bin/startup-prompt" --view handover 2>/dev/null | grep -c '^  journal ')" = 1

cp journal.org before
check "a blank title is refused" status 1 sh -c "printf 'Body.\n' | '$bin/wrap-up' -- ' '"
check "an empty handover is refused" status 1 sh -c "printf '' | '$bin/wrap-up' -- 'Empty'"
check "and said so on stderr" \
    sh -c "printf '' | '$bin/wrap-up' -- 'Empty' 2>&1 >/dev/null | grep -q 'needs the handover'"
check "a date not written YYYY-MM-DD is refused" \
    status 1 sh -c "printf 'Body.\n' | '$bin/wrap-up' --date 4/3/2030 -- 'Dated'"
check "a refusal writes nothing" cmp -s before journal.org
check "a title without -- is usage" status 2 sh -c "printf 'Body.\n' | '$bin/wrap-up' 'No dashes'"
check "and is told to put -- before the title" \
    sh -c "printf 'Body.\n' | '$bin/wrap-up' 'No dashes' 2>&1 | grep -qx 'wrap-up: put -- before the title'"
check "--help prints the usage" sh -c "'$bin/wrap-up' --help | grep -q '^Usage: wrap-up'"
rm -f before out out2 err
# _index is the CID index fetch keeps, not wrap-up's.
check "no lock, backup or other file is left" \
    test "$(ls -A | sort | tr '\n' ' ')" = ".pos _index journal.org "
check "the archive and its ledger are in .pos" \
    test "$(ls -A .pos | sort | tr '\n' ' ')" = "archive-integrity archives config.yaml "

# A directory with no configuration directory keeps its archive in a
# .clankos/ that has no configuration file.
mkdir shed
(cd shed && printf 'In the shed.\n' | "$bin/wrap-up" -- 'The shed swept' > /dev/null 2>&1)
check "a directory without a configuration directory seals into .clankos" \
    test -f "shed/.clankos/archives/journal/$today-the-shed-swept.org"
check "with its ledger there" test -d shed/.clankos/archive-integrity/ledger
check "and no configuration file is made" sh -c '! ls shed/.clankos/config.* 2>/dev/null'

[ "$failures" -eq 0 ]
