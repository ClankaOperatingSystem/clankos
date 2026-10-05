# The ClankOS container: Emacs with Org, and what Emacs needs to fetch
# packages from Git repositories and from GNU and NonGNU ELPA.
FROM debian:trixie-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        emacs-nox \
        git \
        gnupg \
    && rm -rf /var/lib/apt/lists/*

# Commands run against a garden or project mounted here.
WORKDIR /workspace

CMD ["emacs", "--version"]
