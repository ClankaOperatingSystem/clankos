---
name: clankos-dedupe
description: Resolve tasks that are written more than once in a garden, keeping one copy and what the others said. Use when lint reports a duplicate task, or when asked to remove duplicates. Not for tasks that are alike and not the same, which the person decides between.
---

Two headings with a keyword are duplicates when their text is the
same, whatever the case of the letters. One copy is kept. A dropped
copy's text that differs is placed beneath the kept one, and links to
a dropped copy are pointed at the kept one.

## Run

    scripts/clankos pos-dedupe COMMAND ...

Run the script by its path in this skill's directory, without changing
directory: the files are those beneath the directory the command is
run in.

`scripts/clankos pos-dedupe --help` lists the commands, and
`scripts/clankos clankos-run help pos-dedupe` gives the protocol.

## Resolve in three steps

1. **Plan.** `plan` writes `dedupe.org`, a table for each duplicated
   task with a row for each copy, and a suggestion of which to keep.
   Nothing is changed.
2. **Review.** In each group set act to `keep` for one copy and `drop`
   for the others, or `?` to leave the group alone.
3. **Apply.** `apply --dry-run` reports what would be done; `apply`
   resolves each group that has one keep and at least one drop.

## What to get right

- Keep the copy that is where the task belongs, usually the one in a
  project's file and not the one in the intray.
- A group with a copy in another repository, or with a dropped copy
  linked from one, is left alone. Say so; do not edit that repository.
- If the files changed after the plan was written, make a new plan.
- Read each heading titled "Merged copy from" that an apply leaves,
  and fold its text into the kept task by hand. Lint reports those
  that remain.

## Afterwards

Say how many groups were resolved, merged and left, from the report.
Nothing is committed: the diff is there to be read.
