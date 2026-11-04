#!/usr/bin/env bash
# Check each skill of skills/ as a harness reads it: it says its name,
# which is its directory's; its description is on one line, with no
# colon a YAML reader would trip on; and it carries the script that
# runs the commands. Reads the repository only; the image is not run.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"

for skill in "$repo"/skills/*/; do
    name=$(basename -- "$skill")
    check "$name says its name, which is its directory's" \
        test "$(sed -n '2p' "$skill/SKILL.md")" = "name: $name"
    check "$name has a description on one line, with no colon a YAML reader would trip on" \
        sh -c "sed -n '3p' '$skill/SKILL.md' | grep -q '^description: [^:]*\(:[^ ][^:]*\)*\$'"
    check "$name carries the script that runs the commands" test -x "$skill/scripts/clankos"
done

[ "$failures" -eq 0 ]
