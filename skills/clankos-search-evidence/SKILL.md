---
name: clankos-search-evidence
description: Find where words occur in a garden's archives, whether the files are on disk or held by a keeper, and cite each hit by its ipfs:// link. Use when a record, a passage or a past decision is wanted and its link is not known. Never grep an archive directory for it. Not for files outside an archive, which grep still serves.
---

A garden's archives hold its sealed records. Some are on disk under
`archives/`; others are held by a keeper and not on disk at all, with
only the ledger in the garden. Grep finds nothing in a kept archive,
and a miss there is not evidence that no record exists. The command
below searches both kinds the same way and names each hit by the link
the clankos-read-evidence skill reads.

## Run

    scripts/clankos archive-integrity search ROOT QUERY [--mode MODE] [--limit N] [--within CID]

Run the script by its path in this skill's directory, without changing
directory. ROOT is the scope to search: `.` for the scope the command
is run in and every project beneath it, or a project's directory for
that project alone. Each hit is printed as `LINK:LINE:TEXT`, grep's
shape with a citation in place of a path.

`scripts/clankos archive-integrity --help` describes `search`, and
`scripts/clankos clankos-run help archive-integrity` says what a
search answers.

## What to get right

- Search the archives with this command and never with grep over an
  archive directory. Grep over canon, the files outside the archives,
  is still the right tool.
- Literal is the default and finds the query's characters as written,
  case and all. `--mode regex` takes a POSIX extended regular
  expression, as `grep -E` does.
- Exit 1 means no hit. It is not an error, and not proof that nothing
  was written about it: try other words before concluding anything.
  Exit 2 is a refusal, printed on standard error; read it.
- `--within CID` narrows a search to one sealed item, file or archive,
  which a document's link names.
- A kept archive is searched by its keeper, which may need a sign-in.
  Signing in opens a browser and is not for an agent to run: say that
  it is needed.
- Searching every archive under a scope asks each keeper in turn and
  can take a minute or two. Search a project's directory when the
  record is known to be that project's.

## Afterwards

Cite a hit by its link, as `ipfs://CID/PATH`, and read the file with
the clankos-read-evidence skill before relying on more than the line
shown. Do not replace the link with a path.
