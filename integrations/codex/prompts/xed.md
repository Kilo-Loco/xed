---
description: Open the current project in Xcode, like `xed` in the terminal
argument-hint: "[dir|file...] [--branch <name>] [--pull] [-l <line>] [-b] [-c]"
---

Run this in the shell, exactly as written:

```sh
xed-open $ARGUMENTS
```

Then report the outcome in one line and stop.

- It printed `Opened <target> in Xcode.` — say that, and stop. Do not summarize
  the project, read files, or offer next steps.
- It printed a note about the branch being behind its upstream, or a reason it
  did not pull — repeat it and stop. Do not `git pull`, `git fetch`, stash, or
  reconcile anything by hand.
- It failed — relay the error verbatim. If it listed several candidates, ask
  which one to open; otherwise stop, do not try to fix the project.
- `xed-open: command not found` — it is not on `PATH`. Say so and point at
  `install.sh` from https://github.com/Kilo-Loco/xed rather than hunting for the
  script or reimplementing what it does.
