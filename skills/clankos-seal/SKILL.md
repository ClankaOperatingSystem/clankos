---
name: clankos-seal
description: Seal a finished record or a piece of evidence into a garden's archive, so that it never changes and can be cited by its content. Use when a handover, research, a decision record or other evidence is to be kept, or when an archive is to be checked. Not for a document still being revised, which stays outside the archive.
---

An archive holds sealed items. A sealed item never changes, and a
ledger beside the archive lets any change be noticed. So sealing is
done in three steps, and what is sealed is what was read.

A scope's archive is `archives/` in its configuration directory, the
one of `.clanka/`, `.clankos/` and `.pos/` that holds its
`config.yml` or `config.yaml`, and its ledger and checkpoints are in
`archive-integrity/` beside it. A scope with no configuration
directory gets `.clankos/` at its first seal.

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
   input. DESTINATION is a path in the scope's archive, such as
   `.clanka/archives/reviews/2026-01-01-garden.org`. It prints a plan
   and changes nothing. Save the plan to a file exactly as printed, in
   a directory whose name begins with an underscore.
2. **Review.** Read the plan: what goes where, how each link in the
   item is resolved, and what is sealed with it.
3. **Apply.** `apply PLAN HASH`, where HASH is the SHA-256 of the saved
   plan file. It is refused if the plan or anything it relied on has
   changed.

Then run `check .` and, when it is clean, `checkpoint .`.

## A directory of files

A directory whose files link to one another is sealed as a
collection. Before planning its seal:

- Give it a `README.org` that holds the line `#+COLLECTION: t` and
  says what the collection holds and where to begin. Links between its
  files then stay as written. Without it, a loop of links among them
  is refused.
- Put in it any record that belongs inside it, such as a close-out.
  A sealed item never grows, so `write-new` refuses a path inside it.
- Change a link to a directory into a link to a file in it, or into
  the directory's name as text. A link to a directory is refused.
- Delete a file whose name begins with a dot, or rename it without
  the dot. Such a file is refused.

## Open tasks in the item

A document that was worked in, an attic or a set of notes, may hold
open tasks. Before planning its seal:

1. `salvage . SOURCE --dry-run` lists them. Close each one that is
   dead, in the file. Place each one whose place is plain, with the
   place skill. Ask the person where it is not plain.
2. `salvage . SOURCE` copies each task still open to the intray and
   leaves the original CANCELLED, each citing the other.

Each copy links to the document, so it then needs the relink below.

## Links to the item from elsewhere

Sealing an item that lies in the garden moves it, so a link to it from
another file would lead nowhere. Before applying the seal:

1. `links-into . SOURCE` shows which files link to the item.
2. If any does, `relink . PLAN`, with the saved seal plan, prints a
   second plan. Save and read it as the first.

Apply the seal plan, then the relink plan, each with `apply PLAN HASH`.
The links then cite the sealed item. A new record made with
`write-new` was never linked to, and needs none of this.

`links-into` finds links in Org files only. Search for the item's path
as text as well, in repositories mounted in the garden too. `relink`
does not rewrite a file of another repository, which changes by that
repository's own process.

## What to get right

- Name the destination as the archive's other items are named. Look
  before choosing.
- After an interruption, apply the same saved plan. Do not make a
  second plan for an item that already has one.
- Salvage before planning the seal, never after: it changes the files
  the plan records.
- Never edit a sealed file. A correction is a new record that cites
  the old one, which `link PATH` gives the citation for.
- A finding from `check` is reported. It is not repaired by rewriting
  a ledger or replacing a file. `repair` restores permissions and
  empty directories only, as after a clone.
- `sign-in` opens a browser and is not for an agent to run.
- A refusal that says relocation-required means that the scope's
  archive or ledger still lies beside its other files, as earlier
  images kept it. Do not seal elsewhere to get round it. Report it:
  the clankos-upgrade skill moves it, with the person's agreement.

## Afterwards

Say what was sealed and where, give its `ipfs://` link, and say whether
the check was clean. Nothing is committed by these commands: the diff
is there to be read.
