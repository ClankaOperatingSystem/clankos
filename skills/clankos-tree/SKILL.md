---
name: clankos-tree
description: Add a responsibility, a project or a product to a garden's tree. Use when asked to start a project, to add an area of life or work, or to bring a repository into the garden. Not for capturing a task, and not for giving a project a directory of its own, which this command does not do.
---

A garden is a tree. A responsibility is an area that is tended and
does not finish. A project is a finite piece of work with an outcome.
A product is a repository the garden works on under that repository's
own rules.

## Run

    scripts/clankos responsibility-tree OPTION ...

Run the script by its path in this skill's directory, without changing
directory: the command adds beneath the responsibility whose directory
it is run in.

`scripts/clankos responsibility-tree --help` gives the options, and
`scripts/clankos clankos-run help responsibility-tree` says what each
addition writes.

## What each addition is

- **A responsibility.** A directory with a configuration and an
  intray, declared in the garden's configuration.
- **A project.** One Org file where the responsibility's projects
  belong, with an empty `OUTCOME` property and a heading for its
  tasks. Making the file is the commitment.
- **A product.** An entry with a path and a remote. The command then
  clones the repository on this machine, with the user's own Git
  credentials; `--no-clone` leaves it for later.

## What to get right

- Decide which the thing is before adding it. Something with an end is
  a project. Something tended without end is a responsibility.
- Run the command in the responsibility the addition belongs to.
- Give the options. Run with none at a terminal, the command asks
  questions, which an agent cannot answer.
- A project whose outcome and first review are known is made whole by
  `scripts/clankos pos-project create`, with its outcome, review and
  next action. After `--project`, write those in the file by hand. The
  start-up views name a project that has no review.
- A project that needs more than one file is promoted with
  `scripts/clankos pos-project promote`.
- Ask before adding a responsibility. It changes the shape of the
  garden.

## Afterwards

Say what was added and where. Nothing is committed: the diff is there
to be read.
