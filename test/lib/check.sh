# Sourced by the tests. Makes a new workspace under _test/ in the
# repository, since Docker may share only some host directories, starts
# in it, and removes it on exit. The image is the one CLANKOS_IMAGE names.
# shellcheck shell=bash

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
bin=$repo/bin
mkdir -p "$repo/_test"
work=$(mktemp -d "$repo/_test/$(basename -- "$0" .sh).XXXXXX")
# The cache clankos-run mounts goes beside it, not in the user's own.
XDG_CACHE_HOME=$(mktemp -d "$repo/_test/cache.XXXXXX")
export XDG_CACHE_HOME
trap 'chmod -R u+w "$work" "$XDG_CACHE_HOME"; rm -rf "$work" "$XDG_CACHE_HOME"' EXIT
cd "$work" || exit 1

failures=0

# check NAME COMMAND ...: report whether COMMAND succeeds.
check() {
    if "${@:2}"; then
        echo "ok    $1"
    else
        echo "FAIL  $1"
        failures=$((failures + 1))
    fi
}

# status N COMMAND ...: whether COMMAND exits N, its output discarded.
status() {
    local expected=$1
    shift
    "$@" >/dev/null 2>&1
    [ $? -eq "$expected" ]
}

sha256() {
    if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1
}

owner() {
    stat -c %u "$1" 2>/dev/null || stat -f %u "$1"
}
