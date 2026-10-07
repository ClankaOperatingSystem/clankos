#!/usr/bin/env bash
# A mounted responsibility keeps its existing agent layout.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.org
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.org

mkdir -p origin/.clanka origin/.claude/skills origin/.agents
git -C origin init -q -b master
printf 'pos: 2\nprojects: projects/\n' > origin/.clanka/config.yml
printf '# Generate a PDF\nUse tools/generate_pdf.py.\n' > origin/.claude/skills/generate-pdf.md
printf 'This path belongs to the repository.\n' > origin/.agents/skills
git -C origin add .
git -C origin commit -qm 'Add existing agent layout'
origin=$work/origin

mkdir -p garden/.clanka garden/.agents/skills/example
cd garden || exit 1
git init -q -b master
printf 'pos: 2\nprojects: projects/\n' > .clanka/config.yml
printf '%s\n' '---' 'name: example' 'description: An example.' '---' > .agents/skills/example/SKILL.md
git clone -q "$origin" mounted

"$bin/responsibility-tree" --product "mounted=$origin" > out 2>&1
check "mounting a repository with its own skills succeeds" test $? -eq 0
check "an existing layout is not a tree finding" sh -c '! grep -q "^finding" out'
check "the Claude skill stays in place" cmp -s \
    "$origin/.claude/skills/generate-pdf.md" mounted/.claude/skills/generate-pdf.md
check "the agent skills path stays a file" cmp -s \
    "$origin/.agents/skills" mounted/.agents/skills
check "the mounted repository is unchanged" test -z "$(git -C mounted status --porcelain)"

"$bin/responsibility-tree" --product "mounted=$origin" > out 2>&1
check "a repeated run succeeds" test $? -eq 0
check "a repeated run reports no findings" sh -c '! grep -q "^finding" out'
check "a repeated run preserves the mounted repository" test -z "$(git -C mounted status --porcelain)"

[ "$failures" -eq 0 ]
