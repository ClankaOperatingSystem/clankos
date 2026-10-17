#!/usr/bin/env bash
# Check that each script in bin/ and each command in libexec/ has its
# pieces: a line in the image's account of a garden, a document under
# docs/, a --help that names the document, and a test that names it,
# which is how test/select finds the tests a change to it bears on;
# that each skill is in the account; and that the groups hold what
# they say: a test in test/garden installs skills, and one in
# test/commands does not. Reads the repository only; the image is not
# run. Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"

account=$repo/docs/clankos.txt
tests=("$repo"/test/commands/*.sh "$repo"/test/garden/*.sh "$repo"/test/docs/*.sh)

# named NAME: whether a test runs NAME, as test/select reads it.
named() { grep -qE "bin/$1([^a-z-]|\$)|clankos-run\"? +$1([^a-z-]|\$)" "${tests[@]}"; }

for script in "$repo"/bin/*; do
    name=${script##*/}
    check "$name is listed in the image's account of a garden" grep -q "^    $name " "$account"
    case $name in
        clankos-run|clankos-install|install.sh) continue ;;
    esac
    check "$name has a document" test -f "$repo/docs/$name.txt"
    check "$name --help names it" sh -c "'$script' --help | grep -qF '\"clankos-run help $name\"'"
done

# run starts the others, pos-emacs is what the pos commands start,
# install-sources is what install reads, and clankos-install is what
# clankos-run reads for install and methodology; install.sh pulls the
# image.
for command in "$repo"/libexec/* "$repo"/bin/*; do
    name=${command##*/}
    case $name in run|pos-emacs|install-sources|clankos-install|install.sh) continue ;; esac
    check "$name is named by a test" named "$name"
done

for skill in "$repo"/skills/*/; do
    name=$(basename -- "$skill")
    check "$name is listed in the image's account of a garden" grep -q "^    $name " "$account"
done

for test in "$repo"/test/garden/*.sh; do
    check "garden/$(basename -- "$test") installs skills" grep -qx 'image_remote' "$test"
done
for test in "$repo"/test/commands/*.sh; do
    check "commands/$(basename -- "$test") installs none" \
        sh -c "! grep -qE '^image_remote\$|clankos-run\"? +(install|methodology)([^a-z-]|\$)|bin/initiate' '$test'"
done

[ "$failures" -eq 0 ]
