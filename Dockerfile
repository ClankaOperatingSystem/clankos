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
# one commit, so that an image tag names one of each: markdown-mode 2.8,
# yaml 1.2.4, and org-roam 2.3.1 with what it requires, compat 31.1.0.0,
# cond-let 1.1.5, llama 1.0.6, dash 2.20.0, emacsql 4.4.2, magit-section
# 4.7.1, the one file kept of magit, and transient 0.13.8, which
# magit-section wants newer than Emacs ships. All are byte-compiled,
# poslib with warnings as errors; of emacsql, the files for SQLite,
# since the others want servers the image has not. org-roam's manual
# and tests are not kept.
ARG POSLIB_COMMIT=6da46dda452db3f23f0ddf9eec4c36e85c9babe8
ARG MARKDOWN_MODE_COMMIT=f5d520b3ee7722dd2231ab586ba51d8eb166e49b
ARG YAML_COMMIT=5546f36bde24a9a8c1934e0f6ce205cd41d72537
ARG COMPAT_COMMIT=90880f81419577e1d3f68424d2a3adf31e6d663e
ARG COND_LET_COMMIT=09292a77001434f59ab55c775dec2b98cb18d028
ARG LLAMA_COMMIT=6850d0c91b629da14fdff2300c222289d1a0029a
ARG DASH_COMMIT=b96413794b2fa9e37a17ca0d6fe0d0396006d3ec
ARG EMACSQL_COMMIT=7a4c607912c8fdd1fca4def4915d68f43b12d4da
ARG MAGIT_COMMIT=659f89955cf60fe3d4326d881c412df06c69680d
ARG TRANSIENT_COMMIT=0cacc84ff0c7df126e194666ff8b8a1e6082e796
ARG ORG_ROAM_COMMIT=7ce95a286ba7d0383f2ab16ca4cdbf79901921ff
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
    && fetch compat https://github.com/emacs-compat/compat.git "$COMPAT_COMMIT" \
    && fetch cond-let https://github.com/tarsius/cond-let.git "$COND_LET_COMMIT" \
    && fetch llama https://github.com/tarsius/llama.git "$LLAMA_COMMIT" \
    && fetch dash https://github.com/magnars/dash.el.git "$DASH_COMMIT" \
    && fetch emacsql https://github.com/magit/emacsql.git "$EMACSQL_COMMIT" \
    && fetch magit https://github.com/magit/magit.git "$MAGIT_COMMIT" \
    && mkdir magit-section && mv magit/lisp/magit-section.el magit/COMMIT magit-section/ \
    && rm -rf magit \
    && fetch transient https://github.com/magit/transient.git "$TRANSIENT_COMMIT" \
    && fetch org-roam https://github.com/org-roam/org-roam.git "$ORG_ROAM_COMMIT" \
    && rm -rf org-roam/doc org-roam/tests \
    && emacs -Q --batch -l lisp/clankos-packages.el \
        -f batch-byte-compile markdown-mode/markdown-mode.el yaml/yaml.el \
        compat/compat.el compat/compat-2*.el compat/compat-3*.el compat/compat-macs.el \
        cond-let/cond-let.el llama/llama.el dash/dash.el \
        emacsql/emacsql-compiler.el emacsql/emacsql.el emacsql/emacsql-sqlite.el \
        emacsql/emacsql-sqlite-builtin.el transient/lisp/transient.el \
        magit-section/magit-section.el org-roam/*.el \
    && emacs -Q --batch -l lisp/clankos-packages.el \
        --eval '(setq byte-compile-error-on-warn t)' \
        -f batch-byte-compile poslib/lisp/*.el \
    && rm -rf /root/.emacs.d

# The commands, which bin/clankos-run starts through run; the scripts
# that start them from a host, which initiate gives a garden; and the
# documents, which help prints.
COPY libexec/ /usr/local/libexec/clankos/
COPY bin/ /usr/local/share/clankos/bin/
COPY docs/ /usr/local/share/clankos/docs/

CMD ["emacs", "--version"]
