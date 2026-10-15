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

# image_remote: install fetches the image's skills from the repository
# the image was built from, at its commit. Serve that repository from a
# bare clone of this one in remotes/: git in the containers reads the
# rewrite from $XDG_CONFIG_HOME/git/config, which clankos-run passes on,
# and the workspace is the whole work directory, so that both see it.
# The image must be built from a commit of this repository.
image_remote() {
    export CLANKOS_WORKSPACE=$work XDG_CONFIG_HOME=$work/config
    mkdir -p "$XDG_CONFIG_HOME/git" "$work/remotes"
    [ -d "$work/remotes/clankos.git" ] || git clone -q --bare "$repo" "$work/remotes/clankos.git"
    printf '[url "file://%s/remotes/clankos.git"]\n\tinsteadOf = https://github.com/ClankaOperatingSystem/clankos.git\n' \
        "$work" >> "$XDG_CONFIG_HOME/git/config"
}
