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
