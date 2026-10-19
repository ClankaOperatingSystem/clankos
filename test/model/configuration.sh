#!/usr/bin/env bash
# The configuration: the file a node holds, which names the image the
# node runs and declares its sources.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
. "$repo/test/lib/model.sh"

check "A node's configuration is one file, config.yaml or config.yml, in a directory of the node named .clanka, .clankos or .pos." \
    ert pos-path/a-configuration-may-be-at-one-of-six-paths
check "The configuration names the image the node runs." fixture image
check "The configuration declares the node's sources under methodologies." fixture sources

[ "$failures" -eq 0 ]
