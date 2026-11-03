#!/usr/bin/env bash
# responsibility-tree counts method zero, the image's own skills, as
# declared, and still reports a skill from an undeclared source.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
image_remote
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GH_TOKEN=unused
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.org
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.org
mkdir -p garden/.clanka && cd garden && git init -q -b master
printf 'pos: 2\nprojects: projects/\n' > .clanka/config.yml
git add . && git commit -qm 'Add a garden'

"$bin/clankos-run" apply-v1 > ../out 2>&1
check "apply installs method zero" test -f .agents/skills/start-up/SKILL.md
"$bin/responsibility-tree" --no-clone > ../out 2>&1
check "responsibility-tree succeeds" test $? -eq 0
check "and finds no method-zero skill wild-caught" sh -c "! grep -q 'wild-caught' ../out"

python3 - <<'PY'
import json
lock = json.load(open('skills-lock.json'))
lock['skills']['stray'] = {'source': 'example/stray', 'ref': 'v1',
                           'sourceType': 'github', 'skillPath': 'skills/stray/SKILL.md'}
json.dump(lock, open('skills-lock.json', 'w'), indent=2)
PY
"$bin/responsibility-tree" --no-clone > ../out 2>&1
check "a skill from an undeclared source is still wild-caught" \
    grep -qx 'finding   wild-caught skills-lock.json (stray: from example/stray, which is not declared)' ../out
check "and it alone" test "$(grep -c 'wild-caught' ../out)" -eq 1
[ "$failures" -eq 0 ]
