#!/usr/bin/env bash
# The skills in a tree three repositories deep: a garden, a
# responsibility mounted in it, and a project mounted in that, which
# has a methodology with a skill of its own. Each repository has its
# configuration under a different name.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"
image_remote

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.org
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.org

mkdir -p grand/.pos grand/methodologies/adr/skills/adr-record
git -C grand init -q -b master
printf 'pos: 2\nmethodologies: methodologies/\nbin: bin\nchildren:\n  - path: methodologies/adr\n' \
    > grand/.pos/config.yaml
printf 'methodology: 1\n' > grand/methodologies/adr/methodology.yaml
printf -- '---\nname: adr-record\ndescription: Record a decision.\n---\n' \
    > grand/methodologies/adr/skills/adr-record/SKILL.md
printf '* NEXT In the project\n' > grand/project.org
git -C grand add . && git -C grand commit -qm 'Add a project'

mkdir -p child/.clanka && git -C child init -q -b master
printf 'pos: 2\nprojects: projects/\nchildren:\n  - path: projects/grand\n    remote: %s\n' \
    "$work/grand" > child/.clanka/config.yml
printf '#+TITLE: Intray\n\n* Unsorted\n' > child/intray.org
git -C child add . && git -C child commit -qm 'Add a responsibility'

mkdir -p garden/.clankos garden/home/.pos garden/home/study/.pos
cd garden && git init -q -b master
printf 'pos: 2\nprojects: projects/\nbin: bin\nchildren:\n  - path: child\n    remote: %s\n  - path: home\n' \
    "$work/child" > .clankos/config.yml
printf 'pos: 2\nprojects: projects/\nchildren:\n  - path: study\n' > home/.pos/config.yaml
printf 'pos: 2\nprojects: projects/\n' > home/study/.pos/config.yaml
for dir in . home home/study; do
    printf '#+TITLE: Intray\n\n* Unsorted\n' > "$dir/intray.org"
done
git clone -q "$work/child" child
git clone -q "$work/grand" child/projects/grand
git add .clankos home intray.org && git commit -qm 'Add a garden'

for dir in . child child/projects/grand; do
    (cd "$dir" && "$bin/clankos-run" install > "$work/out" 2> "$work/err")
    check "$dir: install succeeds" test $? -eq 0
done
"$bin/clankos-run" refresh > ../out 2> ../err
check "refresh succeeds, and says nothing" test $? -eq 0 -a ! -s ../out -a ! -s ../err

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
check "each has the commands where its repository keeps its configuration" \
    test -d .clankos/auto/bin -a -d child/.clanka/auto/bin -a -d child/projects/grand/.pos/auto/bin
check "the methodology's skill is linked in its project alone" \
    test ! -e .agents/skills/adr-record -a ! -e child/.agents/skills/adr-record
check "a responsibility that is a directory of the garden is given nothing of its own" \
    test "$(ls -A home | tr '\n' ' ')" = ".pos intray.org study "

(cd home/study && ../../.agents/skills/capture/scripts/clankos capture -- 'From the study' > ../../../out 2>&1)
check "from a directory two beneath the garden, the garden's skill works on that directory" \
    grep -q 'From the study' home/study/intray.org
(cd child && .agents/skills/capture/scripts/clankos capture -- 'From the child' > ../../out 2>&1)
check "a mounted responsibility's own skill works on it" grep -q 'From the child' child/intray.org
(cd child/projects/grand && .agents/skills/start-up/scripts/clankos start-up --view next > ../../../../out 2>&1)
check "a mounted project's own skill reads the project" grep -q 'NEXT In the project' ../out
"$bin/startup-prompt" --view next > ../out 2>&1
check "from the garden, the project's task is read as the project's" \
    grep -q '^  child/grand  *NEXT In the project$' ../out
check "Git keeps nothing refresh installed, in any of the three" \
    sh -c "! { git status --porcelain --untracked-files=all; git -C child status --porcelain --untracked-files=all; git -C child/projects/grand status --porcelain --untracked-files=all; } | grep -q 'auto/\|bin/\|\.agents/skills/adr-record'"

cd "$work" && git clone -q grand alone && cd alone
"$bin/clankos-run" install > ../out 2> ../err
check "a clone of the project alone has the skills once install has run" \
    test "$(ls .agents/skills | tr '\n' ' ')" = "adr-record $skills"

[ "$failures" -eq 0 ]
