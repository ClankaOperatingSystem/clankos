---
name: clankos-seal
description: Seal a finished record or a piece of evidence into a garden's archive, so that it never changes and can be cited by its content. Use when a handover, research, a decision record or other evidence is to be kept, or when an archive is to be checked. Not for a document still being revised, which stays outside the archive.
---

An archive holds sealed items. A sealed item never changes, and a
ledger beside the archive lets any change be noticed. So sealing is
done in three steps, and what is sealed is what was read.

## Run

    scripts/clankos archive-integrity COMMAND ...

Run the script by its path in this skill's directory, without changing
directory: paths are taken from the directory the command is run in.

`scripts/clankos archive-integrity --help` lists the commands, and
`scripts/clankos clankos-run help archive-integrity` gives the protocol:
what a plan holds, what is refused and why.

## Seal in three steps

1. **Plan.** `seal SOURCE DESTINATION` for a file or directory that is
   there, or `write-new DESTINATION` with a new record on standard
   input. It prints a plan and changes nothing. Save the plan to a
   file exactly as printed, in a directory whose name begins with an
   underscore.
2. **Review.** Read the plan: what goes where, how each link in the
   item is resolved, and what is sealed with it.
3. **Apply.** `apply PLAN HASH`, where HASH is the SHA-256 of the saved
   plan file. It is refused if the plan or anything it relied on has
   changed.

Then run `check .` and, when it is clean, `checkpoint .`.

## What to get right

- Name the destination as the archive's other items are named. Look
  before choosing.
- After an interruption, apply the same saved plan. Do not make a
  second plan for an item that already has one.
- Never edit a sealed file. A correction is a new record that cites
  the old one, which `link PATH` gives the citation for.
- A finding from `check` is reported. It is not repaired by rewriting
  a ledger or replacing a file. `repair` restores permissions and
  empty directories only, as after a clone.
- `sign-in` opens a browser and is not for an agent to run.

## Afterwards

Say what was sealed and where, give its `ipfs://` link, and say whether
the check was clean. Nothing is committed by these commands: the diff
is there to be read.
