#!/usr/bin/env bash
# Check release failures before a runtime can mount the repository.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"
mkdir mock-bin garden
cat > mock-bin/docker <<'DOCKER'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CALLS"
if [ "$1 $2" = 'image inspect' ]; then
    [ "${MISSING:-}" != 1 ] || exit 1
    [ "${3:-}" = --format ] || exit 0
    name=${@: -1}
    if [[ $4 = *org.clankos.role* ]]; then
        case $name in *-skills:*) echo skills ;; *) echo runtime ;; esac
    else
        case $name in *-skills:*) echo "${INSTALLER:-$META}" ;; *) echo "$META" ;; esac
    fi
elif [ "$1" = pull ]; then
    exit 1
else
    echo 'unexpected container execution' >&2
    exit 97
fi
DOCKER
chmod +x mock-bin/docker
export PATH="$work/mock-bin:$PATH" CALLS="$work/calls"
export CLANKOS_IMAGE=example/clankos:v1.2.3
unset CLANKOS_SKILLS_IMAGE
export META='v1.2.3 1111111111111111111111111111111111111111 apply-v1'
cd garden && git init -q
check 'matching fixed pair is accepted' status 0 "$bin/clankos-run" --check-pair
check 'source mismatch refuses apply' status 1 env INSTALLER='v1.2.3 2222222222222222222222222222222222222222 apply-v1' "$bin/clankos-run" apply-v1
check 'release mismatch refuses apply' status 1 env INSTALLER='v1.2.4 1111111111111111111111111111111111111111 apply-v1' "$bin/clankos-run" apply-v1
check 'protocol mismatch refuses apply' status 1 env INSTALLER='v1.2.3 1111111111111111111111111111111111111111 apply-v2' "$bin/clankos-run" apply-v1
check 'missing metadata refuses apply' status 1 env META='<no value> <no value> <no value>' "$bin/clankos-run" apply-v1
check 'missing image refuses with no fallback' status 1 env MISSING=1 "$bin/clankos-run" apply-v1
check 'floating alias is refused' status 1 env CLANKOS_IMAGE=example/clankos:latest "$bin/clankos-run" --check-pair
check 'no refusal starts a container' sh -c '! grep -q "^run " "$CALLS"'
check 'no managed files were written' test "$(ls -A)" = .git
[ "$failures" -eq 0 ]
