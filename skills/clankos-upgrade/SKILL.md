---
name: clankos-upgrade
description: Select a fixed ClankOS release and apply its skills within one repository. Use to upgrade a garden or a mounted repository in its own working copy.
---

Run `scripts/upgrade --image vX.Y.Z` by its path from the repository to
upgrade. Select a published fixed release. The script checks the runtime
and skills image pair, records the target in the root configuration, then
runs apply-v1. It covers local configured nodes and skips separate repositories.
Run it separately in each repository that is to be upgraded.

The script does not stage, commit or push. Review configuration, ownership,
skills and lock changes together, then commit through the repository's normal
workflow. An apply failure leaves the target configuration in place for retry;
report the error and correct it before repeating the command.

## Move archives that lie beside the work

An image whose archive commands keep a scope's archive in its
configuration directory refuses to seal into an archive or ledger that
still lies beside the scope's other files, as `archives/` and
`archive-integrity/`. After installing such an image, from the
garden's root:

1. Run `scripts/clankos archive-integrity relocate-plan .` and show
   the person what it prints: each scope whose archive or ledger would
   move, from where and to where; under `untracked`, the files Git
   does not track, which move with their directory and stay
   untracked, so that the person decides whether any is to be
   committed; and every blocker. It changes nothing, and exits 0 with
   nothing to move, 1 with something to move and 2 with a blocker. It
   does not enter a mounted repository: it lists each under
   `repositories`, and is run in each of those too. A blocker is
   reported, not worked round: a legacy ledger is first rebuilt with
   the clankos-migrate-archive skill, and a declared repository that
   is missing is cloned first.
2. On the person's agreement, run `relocate-apply ROOT` in each
   repository, with its top directory as ROOT: in the garden's own
   repository, and for each mounted repository in a clone of it, on a
   new branch, as that repository takes any other change. It moves
   each scope with `git mv`, or with a plain rename for an archive Git
   ignores, checks it, and writes the managed archive exclusions
   again. It commits nothing.
3. Read `git status` in each: it should show renames only. Commit the
   moves as "Move archives into the configuration directory": in the
   garden's own repository, and in a
   mounted repository's clone on its branch, pushed for a pull
   request. The mount takes the move by a pull once the pull request
   is merged.
4. Run `relocate-plan .` again in each repository. It should exit 0,
   save in a mounted repository whose pull request is still open.

## Afterwards

Report which repository was applied and any incomplete operation. Inspect
`git diff` and `git status`; existing staged work must remain staged and
uncommitted.
