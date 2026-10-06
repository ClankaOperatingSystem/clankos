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

mkdir -p one/sub two three/.pos four five
mkdir one/.clanka
check "a directory holding .clanka is a workspace" sh -c "cd one && [ \"\$('$bin/clankos-run' --show | head -n 1)\" = 'workspace $work/one' ]"
check "it is found from beneath" sh -c "cd one/sub && [ \"\$('$bin/clankos-run' --show | head -n 1)\" = 'workspace $work/one' ]"
check "a directory holding .pos is a workspace" sh -c "cd three && [ \"\$('$bin/clankos-run' --show | head -n 1)\" = 'workspace $work/three' ]"

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

[ "$failures" -eq 0 ]
