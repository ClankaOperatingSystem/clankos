---
name: start-up
description: Open a working session by reading the last handover and what is waiting, then choosing what to do. Use at the first turn of a session, or when asked to get oriented, resume, or say what is next. Not needed again in the same session, and not for a full review.
---

A session opens by choosing what to do. The choice needs the last
session's handover and what is already waiting, and both are slow to
find by opening files.

## Run

    scripts/clankos start-up

Run the script by its path in this skill's directory, without changing
directory: it reads the Org files beneath the directory it is run in,
so run in a responsibility it shows that responsibility's work.

It prints four prompts, then views: the latest handover first, with the
citation of its record, then what is next, waited for, scheduled, due,
to be reviewed, and captured and not yet placed. `scripts/clankos
start-up --help` describes each view and `--view NAME`.

Read the handover the first view cites:

    scripts/clankos archive-integrity fetch ipfs://CID

It says what the last session was for, what it did, what must not be
redone and what is open.

Then see whether anything happened after it. Where the repository has
commits or uncommitted changes newer than the handover, say so and
show what happened since:

    scripts/clankos session-facts COMMIT

with COMMIT the commit that last changed `journal.org`, which `git log
-1 --format=%H -- journal.org` gives. A session that ended without a
wrap-up left no handover, and the facts are what there is. Do not
write a handover for it: its account went with its context.

## What to get right

- Scale the opening to how the session began. Where the purpose is
  already plain, read what bears on it and begin. Do not ask what has
  been answered.
- The views are a bounded reading of saved files, not a review. Say so
  where a choice rests on them.
- Consider circumstances before ranking work: the time there is, fixed
  commitments, attention and energy. Take them from what has been said
  today, not from the last session.
- Offer a few suitable next actions and say why each fits. The newest
  project and the first item in the intray have no precedence.
- An interruption is not lost interest. Work that was set down is still
  wanted until someone says otherwise.
- A task that surfaces and is not for now is captured, not carried in
  mind.

## Afterwards

The opening is done when the purpose and the next move are clear. Then
begin, without asking again for leave to do what was chosen.

`scripts/clankos clankos-run help review` says how a garden is reviewed
when a fuller look is wanted.
