---
name: clankos-review
description: Prepare and conduct a review of a project, a responsibility or the whole garden with the person. Use when a review item falls due, or when asked for a project review, a weekly review or a review of an area. Not for opening an ordinary session, which the start-up skill does.
---

A review is not a command. The person reads and decides; the agent
gathers what is to be read, presents it, and records what is decided.

## Read first

    scripts/clankos clankos-run help review

Run the script by its path in this skill's directory. The document
says how a review item is marked, the three reviews and what each
asks, the weekly and four-weekly passes of the whole, and how a garden
is given its review items.

## Gather

    scripts/clankos startup-prompt --weekly

Run it in the scope under review: at the root for the whole, in a
responsibility's directory for that responsibility. It prints what is
to be placed, what is next, waited for, dated and to be reviewed, the
projects with no next action, what is set aside, and what was finished
in the week. `--view projects` lists each project with its status,
review date, next action and outcome.

Read the scope's own files as well: its purpose, its goals, and each
project's file.

## Conduct

- Present one item at a time, with what bears on it and a suggestion
  where there is one. The decision is the person's.
- Record each decision in the item's own file as it is given: a
  keyword, a date, an outcome, a next action. `scripts/clankos
  pos-state` sets a task's state and records the change, and
  `scripts/clankos pos-project status` a project's.
- Capture what comes to mind with the capture skill. Do not hold it.
- A container's review looks over its children's and does not repeat
  them: a project with a review item of its own is reviewed there.

## Close

Mark the review item done with
`scripts/clankos pos-state FILE:LINE DONE 'What was reviewed'`. Its
repeater moves the date on, so the next review is scheduled by
finishing this one, and the note is kept with the item. If the review
stopped early, leave the item as it is, so that it stays due.

## Afterwards

Say what the review changed and what it left undecided. Nothing is
committed: the diff is there to be read.
