#!/usr/bin/env bash
# Run install, and refresh's comparison of skills-lock.json with the
# configuration, against a garden whose sources are repositories beside
# it. The skills image is the one named as CLANKOS_IMAGE is, with
# -skills after the name.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.org
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.org
unset SSH_AUTH_SOCK GH_TOKEN

# The sources are bare repositories in remotes/, reached as
# https://git.example/NAME.git: the skills CLI reads a ref only from a
# URL of that form. git in the containers reads the rewrite from
# $XDG_CONFIG_HOME/git/config, which clankos-run passes on, and the
# workspace is this whole directory, so that both are seen there.
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
origin loose v1 loose-greet greet
origin clash v1 clash-one hello-greet
origin slot v1 capture
origin twin v1 other-skill
git -C sources/hello branch -q stable && rm -rf remotes/hello.git \
    && git clone -q --bare sources/hello remotes/hello.git

mkdir -p garden/.clanka && cd garden && git init -q -b master
configure() {
    { printf 'pos: 2\nbin: bin\nmethodologies:\n'; printf '%s\n' "$@"; } > .clanka/config.yml
}
hello() { printf '  - source: https://git.example/hello.git\n    ref: %s\n' "$1"; }
shared='  - source: https://git.example/shared.git
    ref: v1
    skills: [share-skill]
    kind: skills-repository
'
configure "$(hello v1)" "$shared"
printf '#+TITLE: Intray\n\n* Unsorted\n' > intray.org
git add .clanka intray.org && git commit -qm 'Add a garden'

# A link an earlier refresh made to one of the image's skills, which Git
# was told to ignore.
mkdir -p .agents/skills
ln -s ../../.clanka/auto/skills/clankos-seal .agents/skills/clankos-seal
printf '/.agents/skills/clankos-seal\n' >> .git/info/exclude

"$bin/clankos-run" install > ../out 2> ../err
status=$?
check "install succeeds" test $status -eq 0
check "the image's skill replaces the earlier link" \
    test ! -L .agents/skills/clankos-seal -a -f .agents/skills/clankos-seal/SKILL.md
check "and Git no longer ignores it" \
    sh -c '! git check-ignore -q .agents/skills/clankos-seal/SKILL.md'
check "a methodology's skills are installed" \
    test -f .agents/skills/hello-greet/SKILL.md -a -f .agents/skills/hello-part/SKILL.md
check "as folders, not links" test ! -L .agents/skills/hello-greet
check "a skills repository's named skill is installed, and no other" \
    test -f .agents/skills/share-skill/SKILL.md -a ! -e .agents/skills/other-skill
check "each is said" grep -qx 'installed hello-greet from https://git.example/hello.git at v1' ../out
check "skills-lock.json records the ref" \
    grep -q '"ref": "v1"' skills-lock.json
check "nothing is committed" test "$(git rev-list --count HEAD)" -eq 1

"$bin/clankos-run" refresh > ../out 2> ../err
check "refresh finds the lock file as declared" test $? -eq 0

git add -A && git commit -qm 'Install the skills'
configure "$(hello v2)" "$shared"
"$bin/clankos-run" refresh > ../out 2> ../err
check "refresh finds a changed ref" test $? -eq 1
check "and names it" grep -qx 'clankos: lock-differs skills-lock.json (hello-greet: v1 installed, v2 declared)' ../err

"$bin/clankos-run" install > ../out 2> ../err
check "install updates a changed ref" grep -q 'v2' .agents/skills/hello-greet/SKILL.md
check "and records it" test "$(grep -c '"ref": "v2"' skills-lock.json)" -eq 2

configure "$(hello v2)" '  - source: https://git.example/shared.git
    ref: v1
    skills: [other-skill]
    kind: skills-repository
'
"$bin/clankos-run" install > ../out 2> ../err
check "install removes a declared source's skill no longer named" test ! -e .agents/skills/share-skill
check "and says so" grep -qx 'removed share-skill' ../out
check "and its lock entry" sh -c '! grep -q share-skill skills-lock.json'
check "and adds the one now named" test -f .agents/skills/other-skill/SKILL.md

# A harness that reads a directory of its own, declared after the skills
# are installed, is given a link to each, and loses them when taken away.
other='  - source: https://git.example/shared.git
    ref: v1
    skills: [other-skill]
    kind: skills-repository'
configure "$(hello v2)" "$other" 'harnesses: [claude-code]'
"$bin/clankos-run" install > ../out 2> ../err
check "a harness declared later is given a link to each skill" \
    test -L .claude/skills/hello-greet -a -L .claude/skills/other-skill
check "and each skill stays a folder in .agents/skills/" \
    test -d .agents/skills/hello-greet -a ! -L .agents/skills/hello-greet
configure "$(hello v2)" "$other"
"$bin/clankos-run" install > ../out 2> ../err
check "a harness taken away loses its links" test ! -e .claude/skills/hello-greet
check "and the skills stay" test -f .agents/skills/hello-greet/SKILL.md

# A source no longer declared leaves its skills wild-caught: install
# leaves them, and refresh names them and exits 0.
git add -A && git commit -qm 'Name another skill'
configure "$(hello v2)"
"$bin/clankos-run" install > ../out 2> ../err
check "install leaves a skill of a source no longer declared" test -f .agents/skills/other-skill/SKILL.md
check "and its lock entry" grep -q '"other-skill"' skills-lock.json
"$bin/clankos-run" refresh > ../out 2> ../err
check "refresh exits 0 for a wild-caught skill" test $? -eq 0
check "and names it" \
    grep -qx 'clankos: wild-caught skills-lock.json (other-skill: from https://git.example/shared.git, which is not declared)' ../err

# A refusal changes nothing but the configuration the test wrote.
git add -A && git commit -qm 'Update the skills'
refused() {
    "$bin/clankos-run" install > ../out 2> ../err
    local status=$?
    [ $status -eq 1 ] && grep -q "$1" ../err \
        && [ "$(git status --porcelain)" = ' M .clanka/config.yml' ]
}
configure "$(hello stable)"
check "a branch as ref is refused" refused 'stable is a branch'
configure "$(hello v2)" '  - source: https://git.example/loose.git
    ref: v1
'
check "a methodology's skill without its prefix is refused" refused 'greet: a skill of https://git.example/loose.git not named loose-NAME'
configure "$(hello v2)" '  - source: https://git.example/loose.git
    ref: v1
    kind: skills-repository
'
"$bin/clankos-run" install > ../out 2> ../err
check "a skills repository is exempt from the prefix" test -f .agents/skills/greet/SKILL.md
git add -A && git commit -qm 'Add loose'
configure "$(hello v2)" '  - source: https://git.example/clash.git
    ref: v1
    kind: skills-repository
'
check "a name two sources supply is refused" refused 'hello-greet: supplied by https://git.example/hello.git and by https://git.example/clash.git'

mkdir -p bin && printf '#!/bin/sh\necho ours\n' > bin/capture && chmod +x bin/capture
git add -f bin/capture && git commit -qm 'Fill the capture slot'
configure "$(hello v2)" '  - source: https://git.example/slot.git
    ref: v1
    kind: skills-repository
'
check "a slot the repository fills is refused" refused 'capture: the repository fills this slot itself'
configure "$(hello v2)" '  - source: https://git.example/twin.git
    ref: v1
    kind: skills-repository
'
check "a source that supplies a wild-caught skill's name is refused" \
    refused 'other-skill: installed from https://git.example/shared.git, which the configuration does not declare'

printf '{"version": 1, "skills": {"stray": {"source": "someone/skills", "sourceType": "github", "computedHash": "0"}}}\n' \
    > ../lock
configure "$(hello v2)"
cp ../lock skills-lock.json
"$bin/clankos-run" pos-lint > ../out 2> ../err
check "the lint does not report a wild-caught entry" sh -c '! grep -q stray ../out'
cd ..

[ "$failures" -eq 0 ]
