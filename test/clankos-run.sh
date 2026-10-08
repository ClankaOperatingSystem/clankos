#!/usr/bin/env bash
# Run bin/clankos-run --show in new workspaces: which directory it takes
# for the workspace and which image it would run. Starts no container.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/lib/check.sh"

# shows WORKSPACE IMAGE: whether --show, run here, prints those two.
shows() {
    [ "$("$bin/clankos-run" --show)" = "workspace $1
image $2" ]
}
latest=ghcr.io/clankaoperatingsystem/clankos:latest
unset CLANKOS_IMAGE CLANKOS_WORKSPACE

# _test/ is inside this repository, so a directory with nothing in it
# takes the repository for its workspace.
check "failing a configuration, the nearest .git is the workspace" shows "$repo" "$latest"

mkdir -p one/sub/.clanka two four five
git -C one init -q .
check "a repository is the workspace" sh -c "cd one && [ \"\$('$bin/clankos-run' --show | head -n 1)\" = 'workspace $work/one' ]"
check "and is from a configured directory of it" sh -c "cd one/sub && [ \"\$('$bin/clankos-run' --show | head -n 1)\" = 'workspace $work/one' ]"

for file in .clanka/config.yaml .clanka/config.yml .pos/config.yaml .pos/config.yml; do
    rm -rf two/.clanka two/.pos
    mkdir -p "two/$(dirname "$file")"
    printf 'pos: 2\nprojects: projects/\nimage: example.org/clankos:v9\n' > "two/$file"
    check "the image pinned in $file is used" \
        sh -c "cd two && [ \"\$('$bin/clankos-run' --show | tail -n 1)\" = 'image example.org/clankos:v9' ]"
done
check "CLANKOS_IMAGE is used before the pin" \
    sh -c "cd two && [ \"\$(CLANKOS_IMAGE=other:1 '$bin/clankos-run' --show | tail -n 1)\" = 'image other:1' ]"

mkdir four/.clanka
printf 'pos: 2\nprojects: projects/\n' > four/.clanka/config.yaml
check "a configuration with no pin runs latest" \
    sh -c "cd four && [ \"\$('$bin/clankos-run' --show | tail -n 1)\" = 'image $latest' ]"

mkdir five/.clanka five/.pos
printf 'pos: 2\n' > five/.clanka/config.yaml
printf 'pos: 2\n' > five/.pos/config.yaml
check "two configurations are refused" sh -c "cd five && '$bin/clankos-run' --show >/dev/null 2>&1; [ \$? -eq 2 ]"

check "CLANKOS_WORKSPACE names the workspace" \
    sh -c "cd one/sub && [ \"\$(CLANKOS_WORKSPACE='$work/one' '$bin/clankos-run' --show | head -n 1)\" = 'workspace $work/one' ]"
check "--show takes no command" status 2 "$bin/clankos-run" --show archive-integrity

# A responsibility that is a directory of a repository is run with the
# whole repository mounted, in its own pinned image. Record Docker's
# arguments only.
mkdir -p nested/child/.clanka mock-bin
git -C nested init -q .
printf 'pos: 2\nprojects: projects/\nimage: example.org/clankos:child\n' > nested/child/.clanka/config.yml
cat > mock-bin/docker <<'MOCK'
#!/bin/sh
printf '%s\n' "$@" > "$DOCKER_ARGS"
MOCK
chmod +x mock-bin/docker
(cd nested/child && PATH="$work/mock-bin:$PATH" DOCKER_ARGS="$work/docker-args" \
    "$bin/responsibility-tree" --project example)
check "a nested tree command mounts the owning repository" grep -qxF "$work/nested:$work/nested" docker-args
check "a nested tree command keeps its own image pin" grep -qxF 'example.org/clankos:child' docker-args

# A configuration that names no image takes the nearest named above it
# in the same repository. A repository mounted beneath does not.
mkdir -p nested/.clanka nested/plain/deep/.clanka nested/mounted/.clanka
printf 'pos: 2\nprojects: projects/\nimage: example.org/clankos:parent\n' > nested/.clanka/config.yml
printf 'pos: 2\nprojects: projects/\n' > nested/plain/deep/.clanka/config.yml
git -C nested/mounted init -q .
printf 'pos: 2\nprojects: projects/\n' > nested/mounted/.clanka/config.yml
check "a directory that names no image takes its container's" \
    sh -c "cd nested/plain/deep && [ \"\$('$bin/clankos-run' --show | tail -n 1)\" = 'image example.org/clankos:parent' ]"
check "a directory that names one keeps it" \
    sh -c "cd nested/child && [ \"\$('$bin/clankos-run' --show | tail -n 1)\" = 'image example.org/clankos:child' ]"
check "a mounted repository that names none runs latest" \
    sh -c "cd nested/mounted && [ \"\$('$bin/clankos-run' --show | tail -n 1)\" = 'image $latest' ]"

[ "$failures" -eq 0 ]
