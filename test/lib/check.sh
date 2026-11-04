# Sourced by the tests. Makes a new workspace under _test/ in the
# repository, since Docker may share only some host directories, starts
# in it, and removes it on exit. The image is the one CLANKOS_IMAGE names.
# The workspace is in a directory of the test's own, so that files a
# test keeps in .. meet no other test's when tests run at once.
# shellcheck shell=bash

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
bin=$repo/bin
mkdir -p "$repo/_test"
own=$(mktemp -d "$repo/_test/$(basename -- "$0" .sh).XXXXXX")
work=$own/work
mkdir "$work"
# The cache clankos-run mounts goes beside it, not in the user's own.
XDG_CACHE_HOME=$own/cache
mkdir "$XDG_CACHE_HOME"
export XDG_CACHE_HOME
trap 'chmod -R u+w "$own"; rm -rf "$own"' EXIT
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

# method_zero [SKILL ...]: the lines under methodologies that declare
# method zero, ClankOS's own skills, at the image's commit: SKILLs, or
# capture, start-up, wrap-up and clankos-bootstrap when none is given.
method_zero() {
    local commit skills
    commit=$(docker run --rm --entrypoint cat "$CLANKOS_IMAGE" /usr/local/share/clankos/source/commit)
    skills=$(IFS=,; echo "${*:-capture,start-up,wrap-up,clankos-bootstrap}" | sed 's/,/, /g')
    printf '  - source: https://github.com/ClankaOperatingSystem/clankos.git\n'
    printf '    ref: %s\n    kind: skills-repository\n    skills: [%s]\n' "$commit" "$skills"
}

# method_zero_all: method_zero with every skill the image holds.
method_zero_all() {
    # shellcheck disable=SC2046
    method_zero $(docker run --rm --entrypoint ls "$CLANKOS_IMAGE" /usr/local/share/clankos/source/skills)
}

# settle: wait until a container reads what the host has just written
# to a file a container has just read or written. Docker Desktop on a
# Mac keeps such a file's size for about a second, and a container
# reading it within that time reads it cut short at its old size.
settle() { sleep 1; }

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
