---
name: clankos-migrate-archive
description: Rebuild an archive that has a legacy ledger, kept inside the archive with no content identifiers, so that it is as a new one. Use when an archive check reports a legacy ledger, or when asked to migrate an archive. Not for an archive that already has its ledger beside it, and not for sealing.
---

Migration is the one time sealed bytes are rewritten. It is done once
for an archive, by a plan that is read before it is applied.

## Run

    scripts/clankos archive-migrate COMMAND ...

Run the script by its path in this skill's directory, without changing
directory: paths are taken from the directory the command is run in.

`scripts/clankos archive-migrate --help` lists the commands, and
`scripts/clankos clankos-run help archive-migrate` gives the protocol:
what is moved, renamed and rewritten, and why.

## Migrate in three steps

1. **Plan.** `plan ARCHIVE ROOT` prints the plan and builds the result
   in `_migrate/` beside the archive, where it can be read. The
   archive is not changed. Save the plan to a file exactly as printed.
2. **Review.** Read the plan with the person: what is removed and
   renamed, the collections, the rumours, how each link is resolved,
   and the files outside the archive that would be edited.
3. **Apply.** `apply PLAN HASH`, where HASH is the SHA-256 of the saved
   plan file.

## What to get right

- Do not apply without the person's word. What migration rewrites was
  sealed.
- After an interruption, apply the same saved plan.
- Run the seal skill's `check` afterwards, and report what it finds.

## Afterwards

Say what the archive now holds, whether the check was clean, and where
the saved plan is. Nothing is committed: the diff is there to be read.
