---
name: clankos-bootstrap
description: Make a Git repository a ClankOS garden with a fixed release and explicit apply. Use to bootstrap a new garden or recover an installation from this standalone bundle.
---

Run `scripts/bootstrap --image vX.Y.Z` from the repository root with a
published release. Git, Bash and Docker must already be available. Report a
missing prerequisite; do not install host software.

The bundle checks both images before writing configuration, then initiates
the garden and runs apply-v1. It installs method zero without optional methods.
An explicit --image updates an existing root image setting before apply. Other
configuration is preserved, including the selected methodology sources.
It creates no auto/bin and needs no other installed skill.

Offer optional methodology sources after bootstrap. Use
`scripts/clankos installation-edit . add SOURCE REF SKILL ...` to record the
selected sources, then `scripts/clankos apply-v1` to install them. Selecting
none leaves method zero alone.

Review the diff and commit through the repository's normal workflow. Nothing
is staged or committed automatically. A failed apply retains intent for retry.
For the protocol, run `scripts/clankos help initiate`.
