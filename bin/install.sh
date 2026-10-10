#!/usr/bin/env bash
set -euo pipefail

image=ghcr.io/clankaoperatingsystem/clankos

usage() {
    cat <<HELP
Usage: install.sh [TAG]
       install.sh --help

Pull the ClankOS image into the local Docker, replacing any older copy
of the same tag, and print the Emacs version it holds. The image is
$image.
TAG is latest unless given: latest follows the master branch, and a
version such as v0.0.1 does not change.

Needs docker on PATH, a running Docker, and the network.
Exit: 0 installed, 1 Docker error (inspect stderr), 2 usage,
127 docker not found.
HELP
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    -*) usage >&2; exit 2 ;;
esac
[ $# -le 1 ] || { usage >&2; exit 2; }
tag=${1:-latest}

command -v docker >/dev/null || {
    echo "install.sh: docker not found" >&2
    exit 127
}

docker pull "$image:$tag" || exit 1
docker run --rm "$image:$tag" emacs --version | head -n 1 || exit 1
