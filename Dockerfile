# The ClankOS container: Emacs with Org and poslib, and git, which poslib
# runs and which fetches what the image is built from.
FROM debian:trixie-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        emacs-nox \
        git \
    && rm -rf /var/lib/apt/lists/*

COPY lisp/ /usr/local/share/clankos/lisp/

# poslib, and the packages it requires, each from its Git repository at
# one commit, so that an image tag names one of each: markdown-mode 2.8
# and yaml 1.2.4. All are byte-compiled, poslib with warnings as errors.
ARG POSLIB_COMMIT=e99d7ef4bc7bd0a81f08e834b32c6cd1897dfddb
ARG MARKDOWN_MODE_COMMIT=f5d520b3ee7722dd2231ab586ba51d8eb166e49b
ARG YAML_COMMIT=5546f36bde24a9a8c1934e0f6ce205cd41d72537
RUN cd /usr/local/share/clankos \
    && fetch() { \
        git init -q "$1" \
        && git -C "$1" fetch -q --depth 1 "$2" "$3" \
        && git -C "$1" checkout -q FETCH_HEAD \
        && rm -rf "$1/.git" \
        && echo "$3" > "$1/COMMIT"; \
    } \
    && fetch poslib https://github.com/ClankaOperatingSystem/poslib.git "$POSLIB_COMMIT" \
    && fetch markdown-mode https://github.com/jrblevin/markdown-mode.git "$MARKDOWN_MODE_COMMIT" \
    && fetch yaml https://github.com/zkry/yaml.el.git "$YAML_COMMIT" \
    && emacs -Q --batch -l lisp/clankos-packages.el \
        -f batch-byte-compile markdown-mode/markdown-mode.el yaml/yaml.el \
    && emacs -Q --batch -l lisp/clankos-packages.el \
        --eval '(setq byte-compile-error-on-warn t)' \
        -f batch-byte-compile poslib/lisp/*.el \
    && rm -rf /root/.emacs.d

# The commands, which bin/clankos-run starts through run, and the
# scripts that start them from a host, which initiate gives a garden.
COPY libexec/ /usr/local/libexec/clankos/
COPY bin/ /usr/local/share/clankos/bin/

CMD ["emacs", "--version"]
