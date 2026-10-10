#!/usr/bin/env bash
# Run bin/initiate, from this repository, against new Git repositories.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

registry=ghcr.io/clankaoperatingsystem/clankos

mkdir defaults && cd defaults && git init -q .
"$bin/initiate" < /dev/null > out 2>&1
check "with no terminal it takes the defaults" \
    test "$(cat .clanka/config.yml)" = "pos: 2
projects: projects/
image: $registry:latest
bin: bin
exclude:
  - archives
  - attic
  - node_modules
  - \"_*\"
  - \".*\""
check "an uncommitted archive is ignored by Git" git check-ignore -q archives/evidence
check "underscore directories are ignored by Git" grep -qxF '_*/' .gitignore
check "the intray has Unsorted" grep -qx '\* Unsorted' intray.org
check "it gives the garden the image's scripts" \
    sh -c 'for s in archive-integrity clankos-run initiate pos-capture responsibility-tree startup-prompt; do [ -x "bin/$s" ] || exit 1; done'
check "the scripts are those of this repository" cmp -s bin/clankos-run "$bin/clankos-run"
check "each is a link to what is installed beside the configuration" \
    test "$(readlink bin/clankos-run)" = ../.clanka/auto/bin/clankos-run
check "what is installed names its version" test -s .clanka/auto/version
check "Git keeps neither the links nor what is installed" \
    sh -c '! git status --porcelain --untracked-files=all | grep -q "bin/\|\.clanka/auto"'
check "and reports the links" grep -qx 'linked    bin/pos-capture' out
check "it makes AGENTS.md, which sends an agent to help" \
    grep -qF 'run `bin/clankos-run help`' AGENTS.md
check "and reports it" grep -qx 'wrote     AGENTS.md' out
check "it commits nothing" test -z "$(git log --oneline 2>/dev/null)"
check "what it wrote is the invoking user's" test "$(owner .clanka/config.yml)" = "$(id -u)"
rm out

# The garden's own scripts work, in the image it was made with.
check "the garden's own capture works" sh -c "bin/pos-capture -- 'First task' >/dev/null 2>&1 && grep -q 'First task' intray.org"
check "the garden's archive check is clean" status 0 bin/archive-integrity check .

rm bin/pos-capture bin/startup-prompt
echo "mine" > bin/pos-capture
"$bin/initiate" --image v9 --archive committed < /dev/null > out 2>&1
check "run again, the configuration is kept" grep -qxF "image: $registry:latest" .clanka/config.yml
check "run again, a link that is missing is made" test -L bin/startup-prompt
check "run again, a file that has a script's name is kept" test "$(cat bin/pos-capture)" = mine
check "and is reported" grep -q 'kept      bin/pos-capture (it is not ClankOS' out
check "as a name taken" grep -qx 'clankos: name-taken bin/pos-capture (untracked)' out
rm bin/pos-capture
check "existing configuration wins over the archive option" git check-ignore -q archives/evidence
check "run again, AGENTS.md is kept" grep -qx 'kept      AGENTS.md' out
check "the block keeps a search within the repository" \
    grep -qx 'Search for files within this repository. Do not search the user.s' AGENTS.md
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
cd ..

mkdir held && cd held && git init -q . && mkdir .clankos
printf 'pos: 2\nprojects: projects/\n' > .clankos/config.yml
"$bin/initiate" --no-tree < /dev/null > out 2>&1
check "a configuration in .clankos makes this a garden already" grep -q '^kept      .clankos/config.yml' out
check "and no second one is written" test ! -e .clanka
cd ..

mkdir pinned && cd pinned && git init -q . && printf 'node_modules/' > .gitignore
printf '# Rules of this repository\n\nNever commit to master.' > AGENTS.md
"$bin/initiate" --image v0.0.1 --archive remote --keeper https://keeper.example/ledgers/a < /dev/null > out 2>&1
check "options answer the questions" \
    test "$(cat .clanka/config.yml)" = "pos: 2
projects: projects/
image: $registry:v0.0.1
bin: bin
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
printf 'v0.0.1\ncommitted\nhealth\n\n\n\n' | "$bin/initiate" --ask >/dev/null 2>&1
check "--ask reads the answers from standard input" \
    test "$(sed -n '3p;11,13p' .clanka/config.yml | tr '\n' '|')" = "image: $registry:v0.0.1|archives:|  - scope: \".\"|    kept: committed|"
check "--ask goes on to the tree" test -f health/.clanka/config.yml
cd ..

mkdir elsewhere && cd elsewhere && git init -q . && mkdir tools
"$bin/initiate" --bin tools < /dev/null >/dev/null 2>&1
check "--bin names where the scripts go" test -x tools/clankos-run -a ! -e bin
check "and the configuration says so" grep -qx 'bin: tools' .clanka/config.yml
check "AGENTS.md names that directory" grep -qF 'run `tools/clankos-run help`' AGENTS.md
cd ..

# A garden made before the commands were links has no line that says
# where they go, and copies of the scripts. A new clone has no links.
mkdir older && cd older && git init -q . && mkdir -p .clanka bin
printf 'pos: 2\nprojects: projects/\n' > .clanka/config.yml
cp "$bin/pos-capture" bin/pos-capture
git add . && git -c user.name=Test -c user.email=test@example.org commit -qm 'An older garden'
"$bin/initiate" --no-tree < /dev/null > out 2>&1
check "an older garden is told where its links go" grep -qx 'bin: bin' .clanka/config.yml
check "its copy of a script is kept and reported, with its commit" \
    grep -q '^clankos: name-taken bin/pos-capture (tracked, added in [0-9a-f]*)$' out
check "its other scripts are linked" test -L bin/clankos-run
git rm -q bin/pos-capture
git add . && git -c user.name=Test -c user.email=test@example.org commit -qm 'Take the links'
git clone -q . ../cloned
cd ../cloned
check "a new clone has no links" test ! -e bin/clankos-run
"$bin/initiate" --no-tree < /dev/null > ../out 2>&1
check "initiate, run in a clone, makes them" test -L bin/clankos-run -a -L bin/pos-capture
check "and changes nothing Git keeps" test -z "$(git status --porcelain)"
cd ..

mkdir plain
check "a directory that is no repository is refused" sh -c "cd plain && '$bin/initiate' </dev/null >/dev/null 2>&1; [ \$? -eq 2 ]"
check "a refusal writes nothing" test -z "$(ls -A plain)"
mkdir bad && (cd bad && git init -q .)
check "an archive kept some other way is refused" sh -c "cd bad && '$bin/initiate' --archive elsewhere </dev/null >/dev/null 2>&1; [ \$? -eq 2 ]"
check "a remote archive without a keeper is refused" sh -c "cd bad && '$bin/initiate' --archive remote </dev/null >/dev/null 2>&1; [ \$? -eq 2 ]"
check "a refused answer writes no configuration" test ! -e bad/.clanka

[ "$failures" -eq 0 ]
