#!/usr/bin/env bash
# Opt in to skills: run methodology add, remove and adopt, and install,
# against a garden whose sources are repositories beside it. The skills
# image is the one named as CLANKOS_IMAGE is, with -skills after the
# name. The rules install follows are clankos-skills/test's; this test
# is of what only the skills CLI in its container shows.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.org
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.org
# The sources are local, and the GitHub CLI is not asked for a token.
unset SSH_AUTH_SOCK
export GH_TOKEN=unused

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
printf ':PROPERTIES:\n:ID: %s\n:END:\n#+TITLE: Intray\n\n* Unsorted\n' intray > intray.org
git add .clanka intray.org && git commit -qm 'Add a garden'
run() { "$bin/clankos-run" methodology "$@" > ../out 2> ../err < /dev/null; }

# A link an earlier refresh made to a skill of the image's, which Git
# was told to ignore.
mkdir -p .agents/skills
ln -s ../../.clanka/auto/skills/hello-greet .agents/skills/hello-greet
printf '/.agents/skills/hello-greet\n' >> .git/info/exclude

run add https://git.example/hello.git v1
check "add succeeds" test $? -eq 0
check "the installed skill replaces the earlier link" \
    test ! -L .agents/skills/hello-greet -a -f .agents/skills/hello-greet/SKILL.md
check "and Git no longer ignores it" \
    sh -c '! git check-ignore -q .agents/skills/hello-greet/SKILL.md'
check "skills-lock.json records the ref" grep -q '"ref": "v1"' skills-lock.json
check "nothing is committed" test "$(git rev-list --count HEAD)" -eq 1
check "and declares the source" grep -qx '  - source: https://git.example/hello.git' .clanka/config.yml
check "and keeps the rest" grep -qx '# The skills.' .clanka/config.yml
check "and installs its skills" \
    test -f .agents/skills/hello-greet/SKILL.md -a -f .agents/skills/hello-part/SKILL.md
check "and says so" grep -qx 'installed hello-greet from https://git.example/hello.git at v1' ../out

run add https://git.example/hello.git v2
check "add of a declared source changes its ref" grep -q 'v2' .agents/skills/hello-greet/SKILL.md
check "and has one entry for it" test "$(grep -c 'hello.git' .clanka/config.yml)" -eq 1
check "and the lock records it" test "$(grep -c '"ref": "v2"' skills-lock.json)" -eq 2

# A harness that reads a directory of its own, declared after the skills
# are installed, is given a link to each, and loses them when taken away.
cp .clanka/config.yml ../config.saved
printf 'harnesses: [claude-code]\n' >> .clanka/config.yml
settle
"$bin/clankos-run" install > ../out 2> ../err
check "a harness declared later leaves each skill a folder in .agents/skills/" \
    test -d .agents/skills/hello-greet -a ! -L .agents/skills/hello-greet
check "and gives the harness a link to it" test -e .claude/skills/hello-greet
cp ../config.saved .clanka/config.yml
settle
"$bin/clankos-run" install > ../out 2> ../err
check "a harness taken away loses its links" test ! -e .claude/skills/hello-greet
check "and the skills stay" test -f .agents/skills/hello-greet/SKILL.md

# A harness's directory that is a link to .agents/skills/ shows each
# skill to that harness: install again changes nothing.
rm -rf .claude && mkdir .claude && ln -s ../.agents/skills .claude/skills
"$bin/clankos-run" install > ../out 2> ../err
check "with a harness's directory linked to .agents/skills/, install changes nothing" \
    sh -c '! grep -q "^removed\|^installed" ../out'
rm -rf .claude

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
