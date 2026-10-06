# The ClankOS container: Emacs with Org and poslib, and what Emacs needs
# to fetch packages from Git repositories and from GNU and NonGNU ELPA.
FROM debian:trixie-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        emacs-nox \
        git \
        gnupg \
    && rm -rf /var/lib/apt/lists/*

COPY lisp/ /usr/local/share/clankos/lisp/

# poslib at one commit, so that an image tag names one poslib. Its
# dependencies come from ELPA when the image is built, signatures checked.
ARG POSLIB_COMMIT=9ff9e5a7f084ae448a4cd2ef4ee91690e3c34e97
RUN cd /usr/local/share/clankos \
    && git init -q poslib \
    && git -C poslib fetch -q --depth 1 \
        https://github.com/ClankaOperatingSystem/poslib.git "$POSLIB_COMMIT" \
    && git -C poslib checkout -q FETCH_HEAD \
    && rm -rf poslib/.git \
    && echo "$POSLIB_COMMIT" > poslib/COMMIT \
    && emacs -Q --batch -l lisp/clankos-packages.el \
        --eval '(setq package-check-signature t)' \
        --eval '(package-refresh-contents)' \
        --eval '(package-install (quote markdown-mode))' \
        --eval '(package-install (quote yaml))' \
        --eval '(setq byte-compile-error-on-warn t)' \
        -f batch-byte-compile poslib/lisp/*.el \
    && rm -rf elpa/gnupg/S.* /root/.emacs.d

# The commands, which bin/clankos-run starts through run.
COPY libexec/ /usr/local/libexec/clankos/

CMD ["emacs", "--version"]
