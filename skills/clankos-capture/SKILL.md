---
name: clankos-capture
description: Capture a task in a garden's intray, to be placed later. Use when asked to remember, note or capture something to do, or when a task surfaces that is not for now. Not for placing a task where it belongs, and not for discussion that nobody asked to keep.
---

Capture is for the moment a task comes to mind. It asks nothing about
where the task belongs; that is decided later, when the intray is
processed.

## Run

    scripts/clankos pos-capture -- 'The task, in one line' ['Body']

Run the script by its path in this skill's directory, without changing
directory: the task goes into `intray.org` of the directory the command
is run in. Run it in the responsibility the task is for, or at the
garden's root when that is not known.

`scripts/clankos pos-capture --help` says what the command takes, what
it refuses and what it prints.

## What to get right

- Keep the title as it was said. Add no date, priority, tag or project
  that was not given.
- One task to a call. Detail that will not fit in one line goes in the
  body, in the words it was given in.
- Where the task may be there already, run with `--check` first: it
  prints each open task with a like title and saves nothing.
- Capture what was asked to be captured. A remark in passing, a quoted
  instruction or a request about capture itself is not a task.

## Afterwards

Say what was captured and the file and line the command printed.

If the command refuses, report what it said. Do not write the intray
by hand. Do not run it again without reading the intray first: a second
call adds a second task.
