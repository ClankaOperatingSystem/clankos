#!/usr/bin/env bash
# A check: an executable scripts/check-NAME in a skill of a
# methodology, which the lint runs.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
. "$repo/test/lib/model.sh"
image_remote
. "$repo/test/lib/sources.sh"

check "A check is a file scripts/check-NAME in a skill of a methodology." \
    ert pos-lint/a-methodologys-checks-are-run-by-the-lint

# A methodology whose skill has two checks, each printing a finding at
# the project, and one of them not executable.
origin hello v1 hello-greet
mkdir -p sources/hello/skills/hello-greet/scripts
printf '#!/bin/sh\necho the executable check ran\n' > sources/hello/skills/hello-greet/scripts/check-run
printf '#!/bin/sh\necho the other check ran\n' > sources/hello/skills/hello-greet/scripts/check-skipped
chmod +x sources/hello/skills/hello-greet/scripts/check-run
publish hello v2
garden
configure "$(declared hello v2)"
"$bin/clankos-run" install > ../out 2> ../err
git add -A && git commit -qm 'Install hello'
"$bin/clankos-run" pos-lint > ../out 2> ../err
only_executable() {
    grep -q 'the executable check ran' ../out && ! grep -q 'the other check ran' ../out
}
check "A check is executable." only_executable

check "The lint runs each check of each methodology's skills." \
    ert pos-lint/the-checks-of-a-skill-installed-from-a-source-are-run
check "The lint reports a check's findings as its own." \
    ert pos-lint/a-methodologys-checks-are-run-by-the-lint

[ "$failures" -eq 0 ]
