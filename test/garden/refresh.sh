#!/usr/bin/env bash
# Run explicit refresh in a tree three repositories deep: a garden, a
# responsibility mounted in it, and a project mounted in that, which has
# a methodology with a skill of its own, each with its configuration
# under a different name; and a product mounted in the garden, which has
# none. Ordinary commands leave installation unchanged.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
image_remote

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.org
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.org

mkdir -p adr/skills/adr-record
git -C adr init -q -b master
printf -- '---\nname: adr-record\ndescription: Record a decision.\n---\n' > adr/skills/adr-record/SKILL.md
git -C adr add . && git -C adr commit -qm 'Add a methodology' && git -C adr tag v1
git clone -q --bare adr "$work/remotes/adr.git"
printf '[url "file://%s/remotes/adr.git"]\n\tinsteadOf = https://git.example/adr.git\n' "$work" >> "$XDG_CONFIG_HOME/git/config"

mkdir -p product && git -C product init -q -b master
printf 'A product.\n' > product/README
git -C product add . && git -C product commit -qm 'Add a product'

# Each repository declares method zero, every skill of it.
zero=$(method_zero_all)
mkdir -p grand/.pos && git -C grand init -q -b master
printf 'pos: 2\nbin: bin\nmethodologies:\n  - source: https://git.example/adr.git\n    ref: v1\n    skills: [adr-record]\n%s\n' "$zero" > grand/.pos/config.yaml
printf ':PROPERTIES:\n:ID: grand\n:END:\n* NEXT In the project\n' > grand/project.org
git -C grand add . && git -C grand commit -qm 'Add a project'

mkdir -p child/.clanka && git -C child init -q -b master
printf 'pos: 2\nprojects: projects/\nchildren:\n  - path: projects/grand\n    remote: %s\nmethodologies:\n%s\n' \
    "$work/grand" "$zero" > child/.clanka/config.yml
printf ':PROPERTIES:\n:ID: %s\n:END:\n#+TITLE: Intray\n\n* Unsorted\n' child-intray > child/intray.org
git -C child add . && git -C child commit -qm 'Add a responsibility'

mkdir -p garden/.clankos garden/home/.pos garden/home/study/.pos
cd garden && git init -q -b master
printf 'pos: 2\nprojects: projects/\nbin: bin\nmethodologies:\n%s\nchildren:\n  - path: child\n    remote: %s\n  - path: product\n    remote: %s\n  - path: home\n' \
    "$zero" "$work/child" "$work/product" > .clankos/config.yml
printf 'pos: 2\nprojects: projects/\nchildren:\n  - path: study\n' > home/.pos/config.yaml
printf 'pos: 2\nprojects: projects/\n' > home/study/.pos/config.yaml
for dir in . home home/study; do
    printf ':PROPERTIES:\n:ID: %s\n:END:\n#+TITLE: Intray\n\n* Unsorted\n' "intray-$dir" > "$dir/intray.org"
done
git clone -q "$work/child" child
git clone -q "$work/grand" child/projects/grand
git clone -q "$work/product" product
# As the tree command does, each child's path is excluded where it is cloned.
printf '/child\n/product\n' >> .git/info/exclude
printf '/projects/grand\n' >> child/.git/info/exclude
git add .clankos home intray.org && git commit -qm 'Add a garden'
# Each configured repository has its skills installed, and committed.
for dir in child/projects/grand child .; do
    (cd "$dir" && "$bin/clankos-run" install > "$work/out" 2> "$work/err")
    check "$dir: install succeeds" test $? -eq 0
    (cd "$dir" && git add -A && git commit -qm 'Install the skills')
done

"$bin/clankos-run" refresh > ../out 2> ../err
check "refresh succeeds, and says nothing" test $? -eq 0 -a ! -s ../out -a ! -s ../err
check "the garden has the image's scripts installed" cmp -s .clankos/auto/bin/clankos-run "$bin/clankos-run"
check "and a link to each where it says bin" test "$(readlink bin/pos-capture)" = ../.clankos/auto/bin/pos-capture
check "a mounted responsibility has them installed too" test -x child/.clanka/auto/bin/clankos-run
check "with no links where it names no bin" test ! -e child/bin
check "nothing is written in a product" test "$(ls -A product)" = ".git
README"
rules=.codex/rules/clankos.rules
check "Codex's rules are written in the garden" test -f $rules
check "with a rule for each link to a command, in three spellings" \
    grep -qxF 'prefix_rule(pattern=[["bin/pos-capture", "./bin/pos-capture", "'"$work"'/garden/bin/pos-capture"]], decision="allow")' $rules
check "and for each skill's scripts/clankos" grep -qF '"./.agents/skills/clankos-lint/scripts/clankos"' $rules
check "and for a mounted responsibility's" grep -qF '"./child/.agents/skills/clankos-lint/scripts/clankos"' $rules
check "a mounted responsibility has its own" \
    grep -qF '"./.agents/skills/clankos-lint/scripts/clankos", "'"$work"'/garden/child/.agents/skills/clankos-lint/scripts/clankos"' child/$rules
check "with no rule for a bin it does not name" sh -c "! grep -q '\"bin/' child/$rules"
check "and none in a product" test ! -e product/.codex
check "no repository sees a change" \
    test -z "$(git status --porcelain)$(git -C child status --porcelain)$(git -C child/projects/grand status --porcelain)$(git -C product status --porcelain)"

skills=$(ls "$repo/skills" | tr '\n' ' ')
check "the garden has each skill" test "$(ls .agents/skills | tr '\n' ' ')" = "$skills"
check "a responsibility mounted in it has each skill" \
    test "$(ls child/.agents/skills | tr '\n' ' ')" = "$skills"
check "a project mounted in that has each skill, and its methodology's" \
    test "$(ls child/projects/grand/.agents/skills | tr '\n' ' ')" = "adr-record $skills"
for dir in . child child/projects/grand; do
    check "$dir: every skill is there to be read" \
        sh -c "for s in '$dir'/.agents/skills/*/SKILL.md; do [ -s \"\$s\" ] || exit 1; done"
done
check "the methodology skill is a regular installed directory" test ! -L child/projects/grand/.agents/skills/adr-record
check "each has the commands where its repository keeps its configuration" \
    test -d .clankos/auto/bin -a -d child/.clanka/auto/bin -a -d child/projects/grand/.pos/auto/bin
check "the methodology's skill is installed in its project alone" \
    test ! -e .agents/skills/adr-record -a ! -e child/.agents/skills/adr-record
check "a responsibility that is a directory of the garden is given nothing of its own" \
    test "$(ls -A home | tr '\n' ' ')" = ".pos intray.org study "

(cd home/study && ../../.agents/skills/capture/scripts/clankos capture -- 'From the study' > ../../../out 2>&1)
check "from a directory two beneath the garden, the garden's skill works on that directory" \
    grep -q 'From the study' home/study/intray.org
(cd child/projects/grand && .agents/skills/start-up/scripts/clankos start-up --view next > ../../../../out 2>&1)
check "a mounted project's own skill reads the project" grep -q 'NEXT In the project' ../out
"$bin/startup-prompt" --view next > ../out 2>&1
check "from the garden, the project's task is read as the project's" \
    grep -q '^  child/grand  *NEXT In the project$' ../out
git checkout -q -- home/study/intray.org


printf 'scribble\n' > .clankos/auto/scribble
printf 'an older version\n' > .clankos/auto/version
rm bin/pos-capture
"$bin/clankos-run" pos-capture -- 'A task' > ../out 2> ../err
check "a command leaves the installed version alone" grep -qx scribble .clankos/auto/scribble
check "and leaves a missing link absent" test ! -L bin/pos-capture
check "and the command then runs" grep -q 'A task' intray.org

printf '%040d\n' 0 > .clankos/auto/commit
"$bin/clankos-run" refresh > ../out 2> ../err
check "an older commit of the same version is replaced" \
    test "$(cat .clankos/auto/commit)" \
    = "$(docker run --rm --entrypoint cat "$CLANKOS_IMAGE" /usr/local/share/clankos/source/commit)"
check "and the lock does not differ" sh -c '! grep -q lock-differs ../err'

rm bin/pos-capture && printf 'mine\n' > bin/pos-capture
"$bin/clankos-run" refresh > ../out 2> ../err
check "a name that is taken exits 1" test $? -eq 1
check "and is named on stderr" grep -qx 'clankos: name-taken bin/pos-capture (untracked)' ../err
check "what has the name is left" test "$(cat bin/pos-capture)" = mine
check "and is no longer a rule" sh -c "! grep -q '\"bin/pos-capture\"' $rules"
"$bin/clankos-run" startup-prompt --view next > ../out 2> ../err
check "ordinary commands do not replay refresh findings" test ! -s ../err
check "and the command runs all the same" grep -q 'START-UP PROMPTS' ../out

# Ordinary commands neither replay nor update the old refresh cache.
printf 'clankos: kept\n' >> .clankos/auto/refresh/said
cp .clankos/auto/refresh/said ../said
printf '# A comment.\n' >> .clankos/config.yml
"$bin/clankos-run" startup-prompt --view next > ../out 2> ../err
check "changed configuration does not trigger installation" test ! -s ../err
check "ordinary commands leave the refresh cache alone" cmp -s ../said .clankos/auto/refresh/said

# A command of the garden's own under a slot's name is its filling of
# the slot: not a name taken.
rm bin/pos-capture bin/wrap-up && printf '#!/bin/sh\necho ours\n' > bin/wrap-up && chmod +x bin/wrap-up
"$bin/clankos-run" refresh > ../out 2> ../err
check "a command of the garden's own under a slot's name exits 0" test $? -eq 0
check "and is not reported" test ! -s ../err
check "and is left as the garden's" test "$(bin/wrap-up)" = ours -a ! -L bin/wrap-up
check "while the other slot commands are linked" test -L bin/capture -a -L bin/start-up

git add -f $rules && git commit -qm 'Track the rules'
"$bin/clankos-run" refresh > ../out 2> ../err
check "a tracked rules file is a name taken" test $? -eq 1
check "and is named on stderr" grep -q "^clankos: name-taken $rules (tracked, added in " ../err
git rm -q --cached $rules && git commit -qm 'Untrack the rules'
"$bin/clankos-run" refresh > ../out 2> ../err
check "untracked again, it is written" test $? -eq 0 -a -f $rules

# A skill of the garden's own, and one edited where it is installed.
mkdir -p .agents/skills/mine && printf '%s\n' '---' 'name: mine' 'description: Mine.' '---' > .agents/skills/mine/SKILL.md
"$bin/clankos-run" refresh > ../out 2> ../err
check "a skill of the garden's own is left alone" test -f .agents/skills/mine/SKILL.md -a ! -L .agents/skills/mine

printf 'Edited.\n' >> .agents/skills/clankos-seal/SKILL.md
"$bin/clankos-run" refresh > ../out 2> ../err
check "a skill edited where it is installed exits 1" test $? -eq 1
check "and is named on stderr" \
    grep -qx 'clankos: lock-differs skills-lock.json (clankos-seal: changed since it was installed)' ../err
cp "$repo/skills/clankos-seal/SKILL.md" .agents/skills/clankos-seal/SKILL.md

# A project that is a directory of the garden uses a methodology, hello,
# whose skill and command are linked where they lie, in the project.
mkdir -p projects/p/.clanka projects/p/methodologies/hello/skills/hello-greet projects/p/methodologies/hello/bin
grep -q '^children:' .clankos/config.yml || printf 'children:\n' >> .clankos/config.yml
printf '  - path: projects/p\n' >> .clankos/config.yml
printf 'pos: 2\nmethodologies: methodologies\nbin: bin\nchildren:\n  - path: methodologies/hello\n' > projects/p/.clanka/config.yml
printf '%s\n' '---' 'name: hello-greet' 'description: Greet.' '---' > projects/p/methodologies/hello/skills/hello-greet/SKILL.md
printf '#!/bin/sh\necho Hello.\n' > projects/p/methodologies/hello/bin/hello-greet && chmod +x projects/p/methodologies/hello/bin/hello-greet
"$bin/clankos-run" refresh > ../out 2> ../err
check "a methodology's skill is linked in the project, where it lies" \
    test "$(readlink projects/p/.agents/skills/hello-greet)" = ../../methodologies/hello/skills/hello-greet
check "and its command, where the project says bin" \
    test "$(readlink projects/p/bin/hello-greet)" = ../methodologies/hello/bin/hello-greet
check "nothing of the methodology is linked at the root" test ! -e .agents/skills/hello-greet
check "Git keeps none of that either" \
    sh -c '! git status --porcelain --untracked-files=all | grep -q "projects/p/\.agents\|projects/p/bin"'
mkdir -p projects/p/methodologies/hello/skills/greet && printf '%s\n' '---' 'name: greet' 'description: Bad.' '---' > projects/p/methodologies/hello/skills/greet/SKILL.md
"$bin/clankos-run" refresh > ../out 2> ../err
check "a skill named without the methodology's prefix is reported" grep -q 'methodology-refused' ../err

# A responsibility may have methodologies, and its skills are linked in it.
mkdir -p work/.clanka work/methodologies/trade/skills/trade-greet
printf '  - path: work\n' >> .clankos/config.yml
printf 'pos: 2\nprojects: projects/\nmethodologies: methodologies\nchildren:\n  - path: methodologies/trade\n' > work/.clanka/config.yml
printf '%s\n' '---' 'name: trade-greet' 'description: Greet.' '---' > work/methodologies/trade/skills/trade-greet/SKILL.md
"$bin/clankos-run" refresh > ../out 2> ../err
check "a responsibility's methodology is linked in the responsibility" \
    test "$(readlink work/.agents/skills/trade-greet)" = ../../methodologies/trade/skills/trade-greet

cd ..

mkdir plain
check "outside a repository refresh does nothing" sh -c "cd plain && CLANKOS_WORKSPACE='$work/plain' '$bin/clankos-run' refresh"

[ "$failures" -eq 0 ]
