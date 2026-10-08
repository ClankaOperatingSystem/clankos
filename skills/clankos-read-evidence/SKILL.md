---
name: clankos-read-evidence
description: Read an archived file that a document cites by an ipfs:// link, whether the file is on disk or held by a keeper. Use when a garden's document cites evidence by ipfs:// and the evidence is needed for the work. Not a search of the archives, and not for files outside an archive.
---

A garden's documents cite archived evidence by content, as
`ipfs://CID` or `ipfs://CID/PATH`. The path a link is shown with is a
label: the file may be on disk, or held by a keeper and not on disk at
all. Reading the link with the command works in both cases, and checks
that the bytes are the ones cited.

## Run

    scripts/clankos archive-integrity fetch 'ipfs://CID/PATH'

Run the script by its path in this skill's directory, without changing
directory. The archive is looked for from the directory the command is
run in upwards, so run it in the scope whose document cites the link.

`scripts/clankos archive-integrity --help` describes `fetch` and `link`.

## What to get right

- Fetch the link as cited, less any Org search suffix (`::...`) or
  fragment (`#...`). Find that heading or passage in what is returned.
- A CID alone that names a collection is a directory and cannot be
  fetched. Fetch a member, as `ipfs://CID/PATH`.
- For an image, a PDF or a long text, send the output to a file in a
  directory whose name begins with an underscore, and check the exit
  status before using it.
- A fetch that fails is evidence that could not be read. It is not an
  empty record and not proof that none exists. Say what could not be
  read and go on without guessing its contents.
- A keeper may need a sign-in, which opens a browser and is not for an
  agent to run. Say that it is needed.
- This reads a file whose link is known. To find a file by what it
  says, use the clankos-search-evidence skill, which searches archives
  on disk and at a keeper alike and cites each hit by a link this
  reads.

## Afterwards

Keep the link as the citation. Do not replace it with a path.
