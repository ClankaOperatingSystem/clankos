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

## Move archives that lie beside the work

An image whose archive commands keep a scope's archive in its
configuration directory refuses to seal into an archive or ledger that
still lies beside the scope's other files, as `archives/` and
`archive-integrity/`. After installing such an image, from the
garden's root:

1. Run `scripts/clankos archive-integrity relocate-plan .` and show
   the person what it prints: each scope whose archive or ledger would
   move, from where and to where, and every blocker. It changes
   nothing. A blocker is reported, not worked round; a legacy ledger
   is first rebuilt with the clankos-migrate-archive skill.
2. On the person's agreement, run `relocate-apply ROOT` in each
   repository, with its top directory as ROOT: in the garden's own
   repository, and for each mounted repository in a clone of it, on a
   new branch, as that repository takes any other change. It moves
   each scope with `git mv`, or with a plain rename for an archive Git
   ignores, checks it, and writes the managed archive exclusions
   again. It commits nothing.
3. Read `git status` in each: it should show renames only. Commit the
   moves as "Move archives into the configuration directory": in the
   garden's own repository where the upgrade's commit went, and in a
   mounted repository's clone on its branch, pushed for a pull
   request. The mount takes the move by a pull once the pull request
   is merged.
4. Run `relocate-plan .` again. It should find nothing to move, save
   in a mounted repository whose pull request is still open.

## What to get right

- Run it on the host, not in a sandbox that denies Docker or the
  network.
- A node whose install is refused is left as it was. Report what
  install said, and do not commit there by hand.
- Push each repository only as that repository's own practice says.

## Afterwards

Say which repositories were committed, which archives were moved and
which wait on a pull request, and repeat what refresh still reports,
if anything.
