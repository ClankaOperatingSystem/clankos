#!/usr/bin/env bash
# A gnome: a methodology that also holds a doctrine, policies and cases,
# which a bugflow server reads. Nothing of ClankOS treats it apart from
# a methodology.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
. "$repo/test/lib/model.sh"

held_by "nothing" "To ClankOS, a gnome is a methodology and nothing more."
held_by "nothing" "ClankOS never reads a gnome's doctrine, policies or cases."
held_by "each gnome's own tests" "A gnome's own tests keep the copies in a skill's references/ equal to their originals."

[ "$failures" -eq 0 ]
