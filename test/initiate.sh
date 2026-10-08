#!/usr/bin/env bash
# Run bin/initiate, from this repository, against new Git repositories.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

registry=ghcr.io/clankaoperatingsystem/clankos

# epoch DATE: DATE, as YYYY-MM-DD, in seconds.
epoch() {
    date -d "$1" +%s 2>/dev/null || date -j -f %Y-%m-%d "$1" +%s
}

mkdir defaults && cd defaults && git init -q .
"$bin/initiate" < /dev/null > out 2>&1
check "with no terminal it takes the defaults" \
    test "$(cat .clanka/config.yml)" = "pos: 2
projects: projects/
image: $registry:latest
exclude:
  - archives
  - attic
  - node_modules
  - \"_*\"
  - \".*\""
check "an uncommitted archive is ignored by Git" git check-ignore -q archives/evidence
check "underscore directories are ignored by Git" grep -qxF '_*/' .gitignore
check "the intray has Unsorted" grep -qx '\* Unsorted' intray.org
check "a root has life.org, with the horizons and the reviews" \
    test "$(grep -c '^\* ' life.org)" = 4 -a "$(grep -c ':review:$' life.org)" = 2
weekly=$(sed -n 's/^SCHEDULED: <\([0-9-]*\) Mon ++1w>$/\1/p' life.org)
monthly=$(sed -n 's/^SCHEDULED: <\([0-9-]*\) Mon ++4w>$/\1/p' life.org)
check "the weekly review repeats from the next Monday" \
    test -n "$weekly" -a "$(( ($(epoch "$weekly") - $(epoch "$(date +%Y-%m-%d)")) / 86400 ))" -ge 1 \
         -a "$(( ($(epoch "$weekly") - $(epoch "$(date +%Y-%m-%d)")) / 86400 ))" -le 7
check "the four-weekly review is first due on the fourth weekly date" \
    test -n "$monthly" -a "$(( ($(epoch "$monthly") - $(epoch "$weekly")) / 86400 ))" = 21
check "and reports it" grep -q '^wrote     life.org' out
check "it gives the garden the image's scripts" \
    sh -c 'for s in archive-integrity clankos-run initiate pos-capture responsibility-tree startup-prompt; do [ -x "bin/$s" ] || exit 1; done'
check "the scripts are those of this repository" cmp -s bin/clankos-run "$bin/clankos-run"
check "it makes AGENTS.md, which sends an agent to help" \
    grep -qF 'run `bin/clankos-run help`' AGENTS.md
check "and reports it" grep -qx 'wrote     AGENTS.md' out
check "it commits nothing" test -z "$(git log --oneline 2>/dev/null)"
check "what it wrote is the invoking user's" test "$(owner .clanka/config.yml)" = "$(id -u)"
rm out

# The garden's own scripts work, in the image it was made with.
check "the garden's own capture works" sh -c "bin/pos-capture -- 'First task' >/dev/null 2>&1 && grep -q 'First task' intray.org"
check "the garden's archive check is clean" status 0 bin/archive-integrity check .

echo "mine" > bin/pos-capture
"$bin/initiate" --image v9 --archive committed < /dev/null > out 2>&1
check "run again, the configuration is kept" grep -qxF "image: $registry:latest" .clanka/config.yml
check "run again, a script that differs is kept" test "$(cat bin/pos-capture)" = mine
check "and is reported" grep -q 'kept      bin/pos-capture (it differs' out
check "existing configuration wins over the archive option" git check-ignore -q archives/evidence
check "run again, AGENTS.md is kept" grep -qx 'kept      AGENTS.md' out
check "run again, life.org is kept" grep -qx 'kept      life.org' out
sed 's/^## ClankOS$/## An older block/' AGENTS.md > edited
{ echo '# Mine'; echo; cat edited; echo; echo 'After.'; } > AGENTS.md
rm edited
"$bin/initiate" --no-tree < /dev/null > out 2>&1
check "a block that differs is brought to the image's" grep -qx '## ClankOS' AGENTS.md
check "and is reported" grep -qx 'updated   the ClankOS block in AGENTS.md' out
check "there is still one block" test "$(grep -c '^<!-- clankos: ' AGENTS.md)" = 2
check "what is outside the block is kept" \
    test "$(head -n 1 AGENTS.md)$(tail -n 1 AGENTS.md)" = '# MineAfter.'
mkdir -p work/.clanka work/archives work/archive-integrity
printf 'pos: 2\nprojects: projects/\n' > work/.clanka/config.yml
printf '\nchildren:\n  - path: work\n' >> .clanka/config.yml
printf 'evidence\n' > work/archives/evidence
printf 'ledger\n' > work/archive-integrity/ledger
"$bin/initiate" --no-tree < /dev/null > out 2>&1
check "rerunning initiate ignores existing child archives" git check-ignore -q work/archives/evidence
check "the ledger stays available to Git" sh -c '! git check-ignore -q work/archive-integrity/ledger'
printf 'pos: 2\nprojects: projects/\narchives:\n  - scope: .\n    kept: committed\n' > work/.clanka/config.yml
"$bin/initiate" --no-tree < /dev/null > out 2>&1
check "a changed child policy removes its generated exclusion" sh -c '! git check-ignore -q work/archives/evidence'
check "the evidence is kept" grep -qx evidence work/archives/evidence
mkdir graft && cd graft && git init -q .
"$bin/initiate" --no-tree < /dev/null > out 2>&1
check "a repository inside a garden is a graft, with no life.org" test -f intray.org -a ! -e life.org
check "and says so" grep -q '^skipped   life.org' out
"$bin/initiate" --root --no-tree < /dev/null > out 2>&1
check "--root overrides what the host found above" test -f life.org
cd ../..

# A garden made before the image wrote life.org.
mkdir older && cd older && git init -q . && mkdir .clanka
printf 'pos: 2\nprojects: projects/\n' > .clanka/config.yml
printf '* Unsorted\n' > intray.org
"$bin/initiate" --no-tree < /dev/null > out 2>&1
check "run in an older garden, life.org is added" test -f life.org
check "and reported" grep -q '^wrote     life.org' out
cd ..

mkdir pinned && cd pinned && git init -q . && printf 'node_modules/' > .gitignore
printf '# Rules of this repository\n\nNever commit to master.' > AGENTS.md
"$bin/initiate" --image v0.0.1 --archive remote --keeper https://keeper.example/ledgers/a < /dev/null > out 2>&1
check "options answer the questions" \
    test "$(cat .clanka/config.yml)" = "pos: 2
projects: projects/
image: $registry:v0.0.1
exclude:
  - archives
  - attic
  - node_modules
  - \"_*\"
  - \".*\"
archives:
  - scope: \".\"
    kept: remote
    url: https://keeper.example/ledgers/a
    sweep: sealed"
check "a remote archive is not ignored" sh -c '! git check-ignore -q archives/evidence'
check "a line is added to .gitignore on a line of its own" grep -qx 'node_modules/' .gitignore
check "an AGENTS.md that is there keeps its content" \
    test "$(sed -n 1,3p AGENTS.md | tr '\n' '|')" = '# Rules of this repository||Never commit to master.|'
check "and gains the block, after a blank line" \
    test "$(sed -n 4,5p AGENTS.md | tr '\n' '|')" = '|<!-- clankos: begin -->|'
check "which is reported" grep -qx 'added     the ClankOS block to AGENTS.md' out
check "the pinned image is the one the garden runs" \
    sh -c "[ \"\$(env -u CLANKOS_IMAGE bin/clankos-run --show | tail -n 1)\" = 'image $registry:v0.0.1' ]"
cd ..

mkdir asked && cd asked && git init -q .
printf 'v0.0.1\ncommitted\n\nhealth\n\n\n\n' | "$bin/initiate" --ask >/dev/null 2>&1
check "--ask reads the answers from standard input" \
    test "$(sed -n '3p;10,12p' .clanka/config.yml | tr '\n' '|')" = "image: $registry:v0.0.1|archives:|  - scope: \".\"|    kept: committed|"
check "--ask goes on to the tree" test -f health/.clanka/config.yml
check "an empty answer to root or graft is root" test -f life.org
cd ..

mkdir elsewhere && cd elsewhere && git init -q . && mkdir tools
"$bin/initiate" --bin tools --graft < /dev/null >/dev/null 2>&1
check "--bin names where the scripts go" test -x tools/clankos-run -a ! -e bin
check "--graft writes no life.org" test ! -e life.org
check "AGENTS.md names that directory" grep -qF 'run `tools/clankos-run help`' AGENTS.md
cd ..

mkdir plain
check "a directory that is no repository is refused" sh -c "cd plain && '$bin/initiate' </dev/null >/dev/null 2>&1; [ \$? -eq 2 ]"
check "a refusal writes nothing" test -z "$(ls -A plain)"
mkdir bad && (cd bad && git init -q .)
check "an archive kept some other way is refused" sh -c "cd bad && '$bin/initiate' --archive elsewhere </dev/null >/dev/null 2>&1; [ \$? -eq 2 ]"
check "a remote archive without a keeper is refused" sh -c "cd bad && '$bin/initiate' --archive remote </dev/null >/dev/null 2>&1; [ \$? -eq 2 ]"
check "an answer that is neither root nor graft is refused" sh -c "cd bad && printf 'latest\nuncommitted\nbranch\n' | '$bin/initiate' --ask >/dev/null 2>&1; [ \$? -eq 2 ]"
check "a refused answer writes no configuration" test ! -e bad/.clanka

[ "$failures" -eq 0 ]
