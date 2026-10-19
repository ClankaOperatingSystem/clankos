# Sourced by the tests, after check.sh and image_remote. Sources are
# bare repositories in remotes/, reached as https://git.example/NAME.git:
# the skills CLI reads a ref only from a URL of that form. git in the
# containers reads the rewrite from $XDG_CONFIG_HOME/git/config, which
# clankos-run passes on, and the workspace is the whole work directory,
# so that both see it. The skills image is the one named as
# CLANKOS_IMAGE is, with -skills after the name.
# shellcheck shell=bash

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.org
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.org
# The sources are local, and the GitHub CLI is not asked for a token.
unset SSH_AUTH_SOCK
export GH_TOKEN=unused

printf '[url "file://%s/remotes/"]\n\tinsteadOf = https://git.example/\n' "$work" \
    >> "$XDG_CONFIG_HOME/git/config"

# publish NAME TAG: commit what sources/NAME holds, tag it TAG, and
# serve it as remotes/NAME.git.
publish() {
    local dir=$work/sources/$1
    git -C "$dir" add -A && git -C "$dir" commit -qm "$2"
    git -C "$dir" tag "$2"
    rm -rf "$work/remotes/$1.git" && git clone -q --bare "$dir" "$work/remotes/$1.git"
}

# origin NAME TAG SKILL ...: the repository NAME holding SKILLs, tagged
# TAG; made, or given a new commit.
origin() {
    local name=$1 tag=$2 dir=$work/sources/$1
    shift 2
    [ -d "$dir" ] || git init -q -b master "$dir"
    rm -rf "$dir/skills"
    for skill in "$@"; do
        mkdir -p "$dir/skills/$skill"
        printf -- '---\nname: %s\ndescription: The %s skill.\n---\nDo it, %s.\n' \
            "$skill" "$skill" "$tag" > "$dir/skills/$skill/SKILL.md"
    done
    publish "$name" "$tag"
}

# configure LINE ...: write the configuration of the repository in the
# working directory, declaring the methodologies LINEs give.
configure() {
    {
        printf 'pos: 2\nbin: bin\n'
        [ $# -eq 0 ] || { printf 'methodologies:\n'; printf '%s\n' "$@"; }
    } > .clanka/config.yml
}

# declared NAME REF [KIND]: the lines that declare the source NAME at
# REF, of KIND.
declared() {
    printf '  - source: https://git.example/%s.git\n    ref: %s\n' "$1" "$2"
    [ $# -lt 3 ] || printf '    kind: %s\n' "$3"
}

# garden: make a repository garden/ in the work directory, with an
# intray, and start in it.
garden() {
    mkdir -p "$work/garden/.clanka" && cd "$work/garden" && git init -q -b master
    printf ':PROPERTIES:\n:ID: %s\n:END:\n#+TITLE: Intray\n\n* Unsorted\n' intray > intray.org
    configure
    git add .clanka intray.org && git commit -qm 'Add a garden'
}
