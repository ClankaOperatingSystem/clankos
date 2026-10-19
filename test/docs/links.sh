#!/usr/bin/env bash
# Check the links between the products' documents: every link from a
# document in one of the repositories below to a file on GitHub, to a
# repository, or to a page of www.clankos.org, names something that is
# there, and a link to a section of a Markdown file names a heading of
# it. This repository is read as it is; the others are cloned from
# GitHub at their default branch. Links within one repository are each
# repository's own check. The image is not run.
# Exit: 0 every check passed, 1 otherwise.
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/../lib/check.sh"

# The repositories whose documents are read, as OWNER/NAME.
readers=(
    ClankaOperatingSystem/clankos
    ClankaOperatingSystem/poslib
    ClankaOperatingSystem/pr-gnome
    ClankaOperatingSystem/repo-gnome
    ClankaOperatingSystem/garden-gnome
    ClankaOperatingSystem/clankos.org
    bugflow/bugflow
)

# checkout OWNER/NAME [BRANCH]: print the directory holding that repository
# at that branch, its default where none is given, cloning it the first
# time; print nothing where it cannot be cloned.
checkout() {
    local dir=$work/clones/$1/${2:-HEAD}
    if [ "$1" = ClankaOperatingSystem/clankos ]; then
        echo "$repo"
        return
    fi
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        git clone -q --depth 1 ${2:+--branch "$2"} "https://github.com/$1.git" "$dir" 2>/dev/null ||
            { rm -rf "$dir"; return; }
    fi
    echo "$dir"
}

# documents DIR: the tracked files of DIR a reader reads.
documents() {
    git -C "$1" ls-files -- '*.md' '*.txt' '*.org' README 'README.*' \
        site.toml template.html ':!requirements*.txt' ':!test/fixtures/*' ':!tests/*'
}

# anchors FILE: the section names GitHub gives the headings of a
# Markdown file, one a line.
anchors() {
    sed -n 's/^#\{1,6\} \{1,\}//p' "$1" | sed 's/ *#* *$//' |
        tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 _-]//g; s/ /-/g'
}

# The links, as SOURCE<TAB>URL, with trailing punctuation removed.
url='https://(www\.)?(github\.com/(ClankaOperatingSystem|bugflow)/[^][:space:]<>()"`'\''*]*|clankos\.org/?[^][:space:]<>()"`'\''*]*)'
for reader in "${readers[@]}"; do
    dir=$(checkout "$reader")
    check "$reader can be cloned" test -n "$dir"
    [ -n "$dir" ] || continue
    documents "$dir" | while read -r file; do
        grep -oE "$url" "$dir/$file" | sed 's/[.,;:]*$//' | sed "s|^|$reader/$file	|"
    done
done | sort -u > links

while IFS='	' read -r source link; do
    case $link in
        https://github.com/*/*/blob/*)
            rest=${link#https://github.com/}
            owner_name=$(printf '%s' "$rest" | cut -d/ -f1-2)
            branch=$(printf '%s' "$rest" | cut -d/ -f4)
            path=$(printf '%s' "$rest" | cut -d/ -f5-)
            section=
            case $path in *'#'*) section=${path#*#}; path=${path%%#*} ;; esac
            dir=$(checkout "$owner_name" "$branch")
            check "$source links to $link, a file that is there" test -f "$dir/$path"
            if [ -n "$section" ] && [ -f "$dir/$path" ]; then
                check "$source links to $link, a section that is there" \
                    grep -qxF -- "$section" <(anchors "$dir/$path")
            fi
            ;;
        https://github.com/*/*/releases/*) ;;
        https://github.com/*/*)
            owner_name=$(printf '%s' "${link#https://github.com/}" | cut -d/ -f1-2)
            owner_name=${owner_name%.git}
            check "$source links to $link, a repository that is there" \
                test -n "$(checkout "$owner_name")"
            ;;
        https://www.clankos.org*|https://clankos.org*)
            path=${link#*clankos.org}
            path=${path#/}
            path=${path%%#*}
            dir=$(checkout ClankaOperatingSystem/clankos.org)
            case $path in
                '') page=index.org ;;
                *.html) page=${path%.html}.org ;;
                */) page=${path}index.org ;;
                *) page=$path ;;
            esac
            check "$source links to $link, a page that is there" test -f "$dir/content/$page"
            ;;
    esac
done < links

[ "$failures" -eq 0 ]
