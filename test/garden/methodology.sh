#!/usr/bin/env bash
# Run methodology add, remove and adopt against a garden whose sources
# are repositories beside it, as test/install.sh does. The skills image
# is the one named as CLANKOS_IMAGE is, with -skills after the name.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.org
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.org
unset SSH_AUTH_SOCK GH_TOKEN

image_remote
printf '[url "file://%s/remotes/"]\n\tinsteadOf = https://git.example/\n' "$work" \
    >> "$XDG_CONFIG_HOME/git/config"

# origin NAME TAG SKILL ...: the repository NAME holding SKILLs, tagged
# TAG; made, or given a new commit.
origin() {
    local name=$1 tag=$2 dir=$work/sources/$1
    shift 2
    [ -d "$dir" ] || git init -q -b master "$dir"
    rm -rf "$dir/skills"
    for skill in "$@"; do
        mkdir -p "$dir/skills/$skill"
        printf -- '---\nname: %s\ndescription: The %s skill.\n---\nDo it, %s.\n' \
            "$skill" "$skill" "$tag" > "$dir/skills/$skill/SKILL.md"
    done
    git -C "$dir" add -A && git -C "$dir" commit -qm "$tag"
    git -C "$dir" tag "$tag"
    rm -rf "remotes/$name.git" && git clone -q --bare "$dir" "remotes/$name.git"
}

origin hello v1 hello-greet hello-part
origin hello v2 hello-greet hello-part
origin shared v1 share-skill other-skill
origin slot v1 capture

mkdir -p garden/.clanka && cd garden && git init -q -b master
printf 'pos: 2\n# The skills.\nbin: bin\n' > .clanka/config.yml
printf '#+TITLE: Intray\n\n* Unsorted\n' > intray.org
git add .clanka intray.org && git commit -qm 'Add a garden'
run() { "$bin/clankos-run" methodology "$@" > ../out 2> ../err < /dev/null; }

run add https://git.example/hello.git v1
check "add succeeds" test $? -eq 0
check "and declares the source" grep -qx '  - source: https://git.example/hello.git' .clanka/config.yml
check "and keeps the rest" grep -qx '# The skills.' .clanka/config.yml
check "and installs its skills" \
    test -f .agents/skills/hello-greet/SKILL.md -a -f .agents/skills/hello-part/SKILL.md
check "and says so" grep -qx 'installed hello-greet from https://git.example/hello.git at v1' ../out

run add https://git.example/hello.git v2
check "add of a declared source changes its ref" grep -q 'v2' .agents/skills/hello-greet/SKILL.md
check "and has one entry for it" test "$(grep -c 'hello.git' .clanka/config.yml)" -eq 1

run add https://git.example/shared.git v1 share-skill --kind skills-repository
check "add installs the skills named" \
    test -f .agents/skills/share-skill/SKILL.md -a ! -e .agents/skills/other-skill
check "and writes the kind" grep -qx '    kind: skills-repository' .clanka/config.yml

run remove https://git.example/hello.git hello-part
check "removing a skill uninstalls it" test ! -e .agents/skills/hello-part
check "and leaves the source naming the rest" grep -qx '    skills: \[hello-greet\]' .clanka/config.yml
check "and the rest installed" test -f .agents/skills/hello-greet/SKILL.md

run remove https://git.example/shared.git
check "removing a source uninstalls its skills, with no terminal to ask" \
    test ! -e .agents/skills/share-skill
check "and says so" grep -qx 'removed share-skill' ../out
check "and takes it out of the configuration" sh -c '! grep -q shared .clanka/config.yml'

run add https://git.example/shared.git v1 share-skill --kind skills-repository
git add -A && git commit -qm 'Install the skills'
run remove https://git.example/shared.git --keep
check "--keep leaves a removed source's skills" test -f .agents/skills/share-skill/SKILL.md
"$bin/clankos-run" refresh > ../out 2> ../err
check "wild-caught" grep -q '^clankos: wild-caught skills-lock.json (share-skill:' ../err

run adopt share-skill
check "adopt succeeds" test $? -eq 0
check "and installs nothing more" test ! -s ../out
check "and declares the source at the ref installed" \
    grep -qx '  - source: https://git.example/shared.git' .clanka/config.yml
check "naming the skill adopted" grep -qx '    skills: \[share-skill\]' .clanka/config.yml
"$bin/clankos-run" refresh > ../out 2> ../err
check "and the skill is no longer wild-caught" sh -c '! grep -q wild-caught ../err'

# A refusal changes nothing.
run add https://git.example/hello.git v2 hello-part
git add -A && git commit -qm 'Install hello-part'
unchanged() { [ -z "$(git status --porcelain)" ]; }
run remove https://git.example/other.git
check "removing a source not declared is refused" test $? -eq 1
check "and changes nothing" unchanged
run remove https://git.example/hello.git hello-greet --keep
check "--keep is refused for a source still declared" test $? -eq 1
check "and changes nothing" unchanged
mkdir -p bin && printf '#!/bin/sh\necho ours\n' > bin/capture && chmod +x bin/capture
git add -f bin/capture && git commit -qm 'Fill the capture slot'
run add https://git.example/slot.git v1 --kind skills-repository
check "where install refuses, so does add" test $? -eq 1
check "and the configuration is put back" unchanged
check "and says so" grep -qx 'methodology: install refused, and .clanka/config.yml is as it was' ../err
cd ..

[ "$failures" -eq 0 ]
