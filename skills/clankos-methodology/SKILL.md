---
name: clankos-methodology
description: Add, remove or adopt a source of skills in a node's configuration, and install the result. Use when asked to install, upgrade or drop a methodology or a skills repository, or to take a skill someone installed with the skills CLI into the configuration. Not for writing a skill.
---

A node declares under `methodologies` the repositories its skills are
installed from. This command changes that list and then runs install,
so that the configuration and the installed skills agree.

## Run

    scripts/clankos clankos-run methodology add SOURCE REF [SKILL ...] [--kind skills-repository]
    scripts/clankos clankos-run methodology remove SOURCE [SKILL ...] [--keep]
    scripts/clankos clankos-run methodology adopt SKILL ...

Run the script by its path in this skill's directory, from the node's
directory. `scripts/clankos clankos-run wild-caught` lists the
wild-caught skills of each repository of the tree, the candidates for
adopt. `scripts/clankos clankos-run help methodology` says what
each change does.

## What to get right

- SOURCE is a git URL and REF a tag or a full commit id. Read the
  tags of the repository for REF; do not guess one.
- Removing a whole source uninstalls its skills. Ask the person
  first, and pass `--keep` if they want to keep them, wild-caught.
- Adopt a skill only when the person wants the configuration to
  manage it. A wild-caught skill may be left as it is.
- A refusal leaves the configuration as it was. Report its message.

## Afterwards

Say what changed in the configuration and what install installed or
removed. The configuration, `skills-lock.json` and `.agents/skills/`
are for the person to commit.
