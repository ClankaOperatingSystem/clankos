# The container install runs the skills CLI in: Node, the CLI at one
# version, and git, which the CLI clones with. The ClankOS image holds
# no Node. bin/clankos-run starts this image for install alone.
FROM node:22-trixie-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
        openssh-client \
    && rm -rf /var/lib/apt/lists/*

# vercel-labs/skills, https://github.com/vercel-labs/skills
ARG SKILLS_VERSION=1.7.2
RUN npm install --global --no-fund --no-audit "skills@$SKILLS_VERSION" \
    && npm cache clean --force

# The CLI sends the names of skills, sources and harnesses to skills.sh
# unless this is set.
ENV DISABLE_TELEMETRY=1

COPY install.mjs /usr/local/libexec/clankos-skills/install.mjs

CMD ["skills", "--version"]
