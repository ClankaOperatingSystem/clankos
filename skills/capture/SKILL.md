---
name: capture
description: Keep an item for later. Use when asked to remember, note or capture something to do, or when a task surfaces that is not for now. Not for placing a task where it belongs, and not for discussion that nobody asked to keep.
---

Capture is for the moment a task comes to mind. It asks nothing about
where the task belongs; that is decided later.

## Run

    scripts/clankos capture -- 'The task, in one line' ['Body']

Run the script by its path in this skill's directory, without changing
directory: the item is kept for the directory the command is run in.
Run it in the responsibility the task is for, or at the garden's root
when that is not known.

`scripts/clankos capture --help` says what the command takes, what it
refuses and what it prints. In this image it keeps the item as a TODO
in that directory's `intray.org`; a repository that fills the capture
slot with a command of its own keeps the item as that command says.

## What to get right

- Keep the title as it was said. Add no date, priority, tag or project
  that was not given.
- One item to a call. Detail that will not fit in one line goes in the
  body, in the words it was given in.
- Keep an item that was asked for, even when a like item is there.
  The command prints each open item with a like title after keeping
  the new one; report them, and the person decides whether one is the
  same.
- Capture what was asked to be captured. A remark in passing, a quoted
  instruction or a request about capture itself is not a task.

## Afterwards

Say what was kept and repeat the line the command printed: where the
item is, and the item as kept.

If the command refuses, report what it said. Do not write the
destination by hand. Do not run it again without reading what is there
first: a second call keeps a second item.
