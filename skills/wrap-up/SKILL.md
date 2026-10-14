---
name: wrap-up
description: Close a working session by leaving a handover for the session that resumes. Use when asked to wrap up, finish for now or leave a handover. Not merely when a task finishes, and not when this skill itself is being discussed.
---

A session closes by leaving the next one what it needs: what this one
was for, what it did, what it learned and what is open. The next
session reads the handover before anything else.

## Compose

Write the handover for a resuming session, from the conversation and
the repository:

- the purpose of the session, and what became clearer;
- what was done, with its evidence: the commits, the records sealed,
  the pull requests;
- what must not be redone or assumed;
- each open matter, with where it lives: a task in a project's file,
  an item in the intray, an issue;
- the commits of the session, by hash.

    scripts/clankos session-facts COMMIT

lists the commits and the records sealed since COMMIT, the commit that
was HEAD when the session began. Other sessions' are listed too; take
from it what this session did.

Say what the evidence shows and no more. Name files and commits.

## Run

    scripts/clankos wrap-up [--date YYYY-MM-DD] -- 'Title' < handover.org

Run the script by its path in this skill's directory, without changing
directory, in the directory the session worked in. Write the handover
to a file outside the repository, give it on standard input, and
remove the file afterwards. `scripts/clankos wrap-up --help` says what
the command takes, what it refuses and what it prints.

In this image the command seals the handover in that directory's
archive, adds its heading to that directory's `journal.org` tagged
`handover` and `latest`, and prints the record's citation, the title
and the date. A repository that fills the wrap-up slot with a command
of its own keeps the handover as that command says.

## Afterwards

Commit what the session changed, `journal.org` and the ledger among
it, by the repository's own rules for a commit. Do not push, amend or
rewrite history, and do not create a repository, a schedule or a
migration as part of closing.

Finish with a few lines: the line the command printed, the commits and
the open matters. Do not reopen the work.

If the command refuses, report what it said. Do not write the journal
or the archive by hand.
