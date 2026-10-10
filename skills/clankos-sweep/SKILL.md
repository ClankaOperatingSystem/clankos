---
name: clankos-sweep
description: Retire a garden's finished items, DONE and CANCELLED, out of the files people work in and into the archive of the week that ended. Use when asked to sweep, tidy finished tasks or close a week, or as the weekly sweep falls due. Not for marking a task done, and not for sealing anything else.
---

Finished items are kept, not deleted. Each week they are moved out of
the working files into that week's archive, by a plan that is read
before it is applied.

## Run

    scripts/clankos pos-sweep COMMAND ...

Run the script by its path in this skill's directory, without changing
directory: the files are those beneath the directory the command is
run in.

`scripts/clankos pos-sweep --help` lists the commands, and
`scripts/clankos clankos-run help pos-sweep` gives the protocol: which
week is swept, and where a scope's items go.

## Sweep in three steps

1. **Plan.** `plan` writes `sweep.org`, titled with the week, with a
   row for each file that has done entries and where they would go.
   Nothing is changed.
2. **Review.** Set act to `sweep` or `skip` for each file. Read the
   entries named below the table: a done entry with an open entry
   beneath it stays where it is.
3. **Apply.** `apply --dry-run` reports what would be archived;
   `apply` archives the done entries of each file marked `sweep`.

Where a scope's sweep is sealed, `close` prints the seal plans of the
weeks that have closed, and `close --apply` seals them. A sealed week
cannot be changed.

## What to get right

- Show the person the plan before the first sweep of a garden, and
  before any `close --apply`.
- A file is left as stale if its done entries changed after the plan
  was written. Make a new plan.
- A project's file may hold done items that are its record of what was
  decided. Ask before sweeping a file where that is so, and mark it
  `skip` if the person wants them kept in place.

## Afterwards

Say how many entries were archived, how many stayed for an open child,
and which files were left, from the report. Nothing is committed: the
diff is there to be read.
