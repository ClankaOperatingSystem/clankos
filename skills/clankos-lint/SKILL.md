---
name: clankos-lint
description: Report what is wrong in a garden's Org files, and run the checks a project's methodologies supply. Use when asked to check, lint or audit a garden's tasks, before a sweep, and after moving or merging tasks. Not for checking an archive, which the seal skill does.
---

Lint reads the garden's Org files and reports. It changes nothing: each
finding is put right by the command or the edit that fits it.

## Run

    scripts/clankos pos-lint

Run the script by its path in this skill's directory, without changing
directory: the files are those beneath the directory the command is
run in.

It prints one finding a line, as `FILE:LINE: MESSAGE`.
`scripts/clankos pos-lint --help` describes the command, and
`scripts/clankos clankos-run help pos-lint` lists every check.

## What each finding asks for

- **A done entry with an open entry beneath it.** Finish or move the
  open one, or reopen the parent.
- **A retired keyword, or a `#+TODO` line.** Change the keyword to one
  of the garden's: TODO, NEXT, WAITING, SOMEDAY, DONE, CANCELLED.
- **A duplicate task.** The dedupe skill resolves it.
- **A merged copy.** Fold its text into the task above it by hand.
- **An intray item that is not TODO.** It has been decided, so the
  place skill moves it; a done one waits for the sweep.
- **A WAITING item that does not say who or what, or since when.** Ask
  the person, and write the answer in the item.
- **A methodology's finding.** It is that methodology's to explain.

## What to get right

- Report the findings before repairing any. Which to repair, and how,
  is the person's to say where a task's meaning is in question.
- A finding in another repository's file is that repository's. Report
  it and leave the file.
- Run lint again after repairs, and say what remains.

## Afterwards

Say how many findings there were, of which kinds, and how many remain.
