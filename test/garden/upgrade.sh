#!/usr/bin/env bash
# Run the upgrade skill's script against a garden with a mounted
# responsibility, both of whose skills were installed from another
# image.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
image_remote

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.org
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.org
# The sources are local, and the GitHub CLI is not asked for a token.
export GH_TOKEN=unused

mkdir -p child/.clanka && git -C child init -q -b master
printf 'pos: 2\nprojects: projects/\n' > child/.clanka/config.yml
git -C child add . && git -C child commit -qm 'Add a responsibility'
mkdir -p garden/.clanka && cd garden && git init -q -b master
printf 'pos: 2\nprojects: projects/\nbin: bin\nchildren:\n  - path: child\n    remote: %s\n' \
    "$work/child" > .clanka/config.yml
git clone -q "$work/child" child
git add .clanka && git commit -qm 'Add a garden'
# Configure mount exclusions explicitly before any broad staging operation.
"$bin/responsibility-tree" --no-clone > ../out 2> ../err
check "tree setup excludes the mounted child" git check-ignore -q child


# Each repository has the image's skills, recorded as from another
# commit, as after a new image is published.
commit=$(docker run --rm "$CLANKOS_IMAGE" cat /usr/local/share/clankos/source/commit)
older=0000000000000000000000000000000000000000
for dir in child .; do
    (cd "$dir" && "$bin/clankos-run" install > /dev/null 2>&1 \
        && sed -i.bak "s/$commit/$older/" skills-lock.json && rm skills-lock.json.bak \
        && git add -A && git commit -qm 'Install the skills')
done
check "fixture does not track the child as a gitlink" test -z "$(git ls-files --stage child)"
"$bin/clankos-run" refresh > ../out 2> ../err
check "refresh finds each skills-lock.json from another commit" \
    sh -c 'grep -q "lock-differs skills-lock.json" ../err && grep -q "lock-differs child/skills-lock.json" ../err'

.agents/skills/clankos-upgrade/scripts/upgrade > ../out 2> ../err
check "upgrade succeeds" test $? -eq 0
check "each repository is committed" \
    sh -c "grep -qx 'committed ./ at ClankOS ${commit:0:7}' ../out && grep -qx 'committed ./child/ at ClankOS ${commit:0:7}' ../out"
check "with the image's commit in its message" \
    test "$(git -C child log -1 --format=%s)" = "Install the skills of ClankOS ${commit:0:7}"
check "skills-lock.json records the image's commit" \
    sh -c "grep -q '$commit' skills-lock.json && grep -q '$commit' child/skills-lock.json && ! grep -q '$older' skills-lock.json child/skills-lock.json"
check "nothing is left to commit" test -z "$(git status --porcelain)$(git -C child status --porcelain)"
"$bin/clankos-run" refresh > ../out 2> ../err
check "and refresh finds nothing" test $? -eq 0 -a ! -s ../err

printf 'An intray.\n' > intray.org && git add intray.org
.agents/skills/clankos-upgrade/scripts/upgrade > ../out 2> ../err
check "run again, there is nothing to do" test $? -eq 0 -a ! -s ../out
check "and what is staged stays staged and uncommitted" test "$(git status --porcelain)" = "A  intray.org"

[ "$failures" -eq 0 ]
