---
name: clankos-start-up
description: Open a working session in a garden by seeing what is waiting and choosing what to do. Use at the start of a session in a garden, or when asked to get oriented, resume, or say what is next. Not needed again in the same session, and not for a full review of the garden.
---

A session opens by choosing what to do. The choice needs to know what
is already waiting, and that is slow to find by opening files.

## Run

    scripts/clankos startup-prompt

Run the script by its path in this skill's directory, without changing
directory: it reads the Org files beneath the directory it is run in,
so run in a responsibility it shows that responsibility's work.

It prints four prompts, then what is next, scheduled, due, to be
reviewed, and captured and not yet placed. `scripts/clankos
startup-prompt --help` describes each view and `--view NAME`.

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
