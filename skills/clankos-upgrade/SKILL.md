---
name: clankos-upgrade
description: Bring a garden and each repository mounted in it to a newly published ClankOS image, installing the image's skills in each and committing them there. Use when a new image is published, or when refresh reports lock-differs for the image's skills. Not for adding or removing a source of skills, which the methodology skill does.
---

Each ClankOS image installs its skills at the commit it was built
from. After a new image is published, every configured repository of
the garden, the root's and each mounted one's, records the old commit,
and refresh reports lock-differs there until the skills are installed
again and committed.

## Run

    scripts/upgrade

Run the script by its path in this skill's directory, from anywhere in
the garden's root repository. It pulls the image and its skills image,
installs the skills in each node whose skills-lock.json differs, and
commits there only the skill folders and skills-lock.json, as
"Install the skills of ClankOS COMMIT". It pushes nothing.

## What to get right

- Run it on the host, not in a sandbox that denies Docker or the
  network.
- A node whose install is refused is left as it was. Report what
  install said, and do not commit there by hand.
- Push each repository only as that repository's own practice says.

## Afterwards

Say which repositories were committed, and repeat what refresh still
reports, if anything.
