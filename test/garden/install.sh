#!/usr/bin/env bash
# Run install, and refresh's comparison of skills-lock.json with the
# configuration, against a garden whose sources are repositories beside
# it. The skills image is the one named as CLANKOS_IMAGE is, with
# -skills after the name.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"

image_remote
. "$repo/test/lib/sources.sh"

origin hello v1 hello-greet hello-part
origin hello v2 hello-greet hello-part
origin shared v1 share-skill other-skill
origin clash v1 clash-one hello-greet
origin twin v1 other-skill

mkdir -p garden/.clanka && cd garden && git init -q -b master
hello() { printf '  - source: https://git.example/hello.git\n    ref: %s\n' "$1"; }
shared='  - source: https://git.example/shared.git
    ref: v1
    skills: [share-skill]
    kind: skills-repository
'
configure "$(hello v1)" "$shared"
printf ':PROPERTIES:\n:ID: %s\n:END:\n#+TITLE: Intray\n\n* Unsorted\n' intray > intray.org
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
check "a harness declared later leaves each skill a folder in .agents/skills/" \
    test -d .agents/skills/hello-greet -a ! -L .agents/skills/hello-greet
configure "$(hello v2)" "$other"
"$bin/clankos-run" install > ../out 2> ../err
check "a harness taken away loses its links" test ! -e .claude/skills/hello-greet
check "and the skills stay" test -f .agents/skills/hello-greet/SKILL.md

# A harness's directory that is a link to .agents/skills/ shows each
# skill to that harness: install again changes nothing.
rm -rf .claude && mkdir .claude && ln -s ../.agents/skills .claude/skills
"$bin/clankos-run" install > ../out 2> ../err
"$bin/clankos-run" install > ../out 2> ../err
check "with a harness's directory linked to .agents/skills/, install again changes nothing" \
    sh -c '! grep -q "^removed\|^installed" ../out'
rm -rf .claude

# A source no longer declared leaves its skills wild-caught: install
# leaves them.
git add -A && git commit -qm 'Name another skill'
configure "$(hello v2)"
"$bin/clankos-run" install > ../out 2> ../err
check "install leaves a skill of a source no longer declared" test -f .agents/skills/other-skill/SKILL.md
check "and its lock entry" grep -q '"other-skill"' skills-lock.json

# A refusal changes nothing but the configuration the test wrote.
git add -A && git commit -qm 'Update the skills'
refused() {
    "$bin/clankos-run" install > ../out 2> ../err
    local status=$?
    [ $status -eq 1 ] && grep -q "$1" ../err \
        && [ "$(git status --porcelain)" = ' M .clanka/config.yml' ]
}
configure "$(hello v2)" '  - source: https://git.example/clash.git
    ref: v1
    kind: skills-repository
'
check "a name two sources supply is refused" refused 'hello-greet: supplied by https://git.example/hello.git and by https://git.example/clash.git'

configure "$(hello v2)" '  - source: https://git.example/twin.git
    ref: v1
    kind: skills-repository
'
check "a source that supplies a wild-caught skill's name is refused" \
    refused 'other-skill: installed from https://git.example/shared.git, which the configuration does not declare'
cd ..

# install gives the skills container GH_TOKEN, or failing it the token
# the GitHub CLI prints. Record the token each container is given.
cd "$work" || exit 1
mkdir -p token/.clanka token-bin
git -C token init -q .
printf 'pos: 2\nprojects: projects/\n' > token/.clanka/config.yml
cat > token-bin/docker <<'MOCK'
#!/bin/sh
[ -t 0 ] || cat > /dev/null
case " $* " in
    *" -e GH_TOKEN "*) printf '%s\n' "$GH_TOKEN" >> "$DOCKER_TOKENS" ;;
    *) printf 'none\n' >> "$DOCKER_TOKENS" ;;
esac
MOCK
cat > token-bin/gh <<'MOCK'
#!/bin/sh
[ "$*" = "auth token" ] && [ -n "$GH_SIGNED_IN" ] && echo from-gh
MOCK
chmod +x token-bin/docker token-bin/gh
# tokens [VAR=VALUE ...]: the token each container of an install is
# given, one a line, with the VARs set.
tokens() {
    rm -f "$work/tokens"
    (cd token && env -u GH_TOKEN PATH="$work/token-bin:$PATH" DOCKER_TOKENS="$work/tokens" \
        GH_SIGNED_IN= "$@" "$bin/clankos-run" install > /dev/null 2>&1)
    tr '\n' ' ' < "$work/tokens"
}
check "install gives the skills container GH_TOKEN" \
    [ "$(tokens GH_TOKEN=set GH_SIGNED_IN=1)" = "none set none " ]
check "and failing it, the GitHub CLI's token" \
    [ "$(tokens GH_SIGNED_IN=1)" = "none from-gh none " ]
check "and no token where the GitHub CLI is signed out" \
    [ "$(tokens)" = "none none none " ]

[ "$failures" -eq 0 ]
