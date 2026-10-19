#!/usr/bin/env bash
# Install and the lock: install copies each source's skills and records
# them in skills-lock.json, which refresh and the lint compare with the
# configuration.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
. "$repo/test/lib/model.sh"
image_remote
. "$repo/test/lib/sources.sh"

origin hello v1 hello-greet hello-part
origin hello v2 hello-greet hello-part
origin shared v1 shared-skill
garden
configure "$(declared hello v1)" "$(declared shared v1)"
"$bin/clankos-run" install > ../out 2> ../err

installed() {
    for skill in hello-greet hello-part shared-skill; do
        [ -f ".agents/skills/$skill/SKILL.md" ] && [ ! -L ".agents/skills/$skill" ] || return 1
    done
}
check "Install copies each source's skills into .agents/skills/." installed
check "The lock is the file skills-lock.json beside .agents/skills/." \
    test -f skills-lock.json -a -d .agents/skills
recorded() {
    grep -A3 '"hello-greet": {' skills-lock.json > ../entry
    grep -q '"source": "https://git.example/hello.git"' ../entry && grep -q '"ref": "v1"' ../entry
}
check "The lock names each skill installed, its source and the ref it was installed at." recorded

git add -A && git commit -qm 'Install the skills'
differs() {
    [ "$1" -eq 1 ] \
        && grep -qx 'clankos: lock-differs skills-lock.json (hello-greet: v1 installed, v2 declared)' ../err
}
configure "$(declared hello v2)" "$(declared shared v1)"
"$bin/clankos-run" refresh > ../out 2> ../err
check "Refresh reports a lock that differs from the configuration." differs $?

configure "$(declared hello v2)"
"$bin/clankos-run" install > ../out 2> ../err
git add -A && git commit -qm 'Leave shared undeclared'
"$bin/clankos-run" refresh > ../out 2> ../err
status=$?
wild_caught='clankos: wild-caught skills-lock.json (shared-skill: from https://git.example/shared.git, which is not declared)'
check "A wild-caught skill is one whose lock entry names a source the configuration does not declare." \
    grep -qx "$wild_caught" ../err
check "Refresh names each wild-caught skill and exits 0." \
    sh -c '[ "$0" -eq 0 ] && grep -qx "$1" ../err' "$status" "$wild_caught"

check "The lint reports a lock entry of a skill that its declared source does not name." \
    ert pos-lint/an-undeclared-entry-of-a-lock-file-is-a-finding
"$bin/clankos-run" pos-lint > ../out 2> ../err
not_reported() {
    ert pos-lint/an-undeclared-entry-of-a-lock-file-is-a-finding && ! grep -q shared-skill ../out
}
check "The lint does not report a wild-caught skill." not_reported

[ "$failures" -eq 0 ]
