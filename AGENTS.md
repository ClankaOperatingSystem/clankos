Commit messages

Terse, in the style of the Linux kernel.

- Subject in the imperative mood: "Add container", not "Added container".
- Subject of 50 characters or fewer, no trailing full stop.
- Prefixes follow the kernel, not "conventional commits". A prefix may
  be used, optionally, to identify the component or subsystem that is
  changed: "Dockerfile: Add gnupg", "bin: Add archive-integrity". It
  never names the kind of change: no "feat:", "fix:", "chore:" or "docs:".
- Body only when the subject is not enough: a blank line, then what the
  change does and why, wrapped at 72 columns.

Pull requests

Every change reaches master through a pull request.

- Never commit to master.
- Work on a branch with a plain descriptive name, such as
  debian-emacs-container. No prefixes such as "feat/" or "fix/".
- Push the branch and open a pull request against master.
- Do not merge it. The maintainer reviews and merges.

Tests

- make check runs the tests that need no container: the Lisp of lisp/,
  with ERT, against poslib at the commit the Dockerfile pins. It takes
  seconds; run it on every change.
- test/run runs the tests in the images, which CLANKOS_IMAGE names. Build
  clankos:test and clankos-skills:test from the same commit first.
