---
name: clankos-place
description: Move the tasks in a garden's intray to the files they belong in. Use when asked to process, clear or sort an intray, or to place a captured task. Not for capturing a task, and not for deciding what a task means, which the person does.
---

An intray holds what was captured and not yet placed. Placing is done
by a plan that is written, read and then applied, so that nothing moves
before it has been seen.

## Run

    scripts/clankos pos-refile COMMAND ...

Run the script by its path in this skill's directory, without changing
directory: the intray is `intray.org` of the directory the command is
run in.

`scripts/clankos pos-refile --help` lists the commands, and
`scripts/clankos clankos-run help pos-refile` gives the protocol: the
plan's table, what is moved and what is left.

## Place in three steps

1. **Plan.** `plan` writes `refile.org`, a table with a row for each
   entry of the intray. Nothing is moved.
2. **Review.** For each row, set act to `move`, file to the target,
   and under to the heading it goes beneath; or leave it `?`. Where
   the task belongs is the person's to say: ask, one entry at a time,
   when it is not plain.
3. **Apply.** `apply --dry-run` reports what would move; `apply` moves
   each `move` entry with its subtree.

One task is moved at once, with no plan, by
`scripts/clankos pos-place TARGET FILE UNDER [STATE]`: the task by its
ID or its file and line, the file and heading it goes beneath, and the
state it then has. It records where the task came from and prints each
link that names the old place. `scripts/clankos pos-place --help` has
the rest.

## What to get right

- A target file and heading must exist. An entry whose target is
  missing, or is another repository's, is not moved, and the report
  counts it.
- If the intray changed after the plan was written, make a new plan.
  An entry is found by its line and heading as the plan recorded them.
- Do not move entries by editing the files by hand while a plan is
  open.
- A task that is NEXT, WAITING or SOMEDAY has been decided and still
  needs a place; a done one is left for the sweep.

## Afterwards

Say how many entries were moved and how many are left, from the
report. Nothing is committed: the diff is there to be read.
