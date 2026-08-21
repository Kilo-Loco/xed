---
name: xed
description: Open a project in Xcode from the current directory — or from the worktree on a given branch — picking the right target (.xcworkspace over .xcodeproj over Package.swift) instead of guessing. Use when the user says "open in Xcode", "xed", "open the workspace/project", "open <branch> in Xcode", or asks to jump to a file or line in Xcode. macOS with Xcode only.
---

# xed

Open the project in Xcode by running:

```sh
xed-open
```

That is the whole job. Run it, report the result in one line, and stop — do not
summarize the project, read files, or offer next steps afterward.

## Arguments

`xed-open` takes the same arguments as `xed(1)`, so pass through whatever the
user asked for:

| They asked for | Run |
| --- | --- |
| the project, the workspace, "open Xcode" | `xed-open` |
| a specific directory | `xed-open SomeDir` |
| a specific file | `xed-open Sources/App.swift` |
| a file at a line | `xed-open -l 42 Sources/App.swift` |
| Xcode left in the background | `xed-open -b` |
| the copy on another branch | `xed-open --branch main` |
| that copy, brought up to date first | `xed-open --branch main --pull` |

`--branch <name>` resolves inside the existing worktree that has that branch
checked out — the main clone counts, so `--branch main` works from a feature
worktree. It never creates a worktree, and it cannot be combined with a path.
If that checkout trails its upstream it says so on stderr and opens it anyway.

`--pull` fast-forwards the checkout to its upstream first. Only pass it when the
user actually asked to update, pull, or get the latest — it touches the network
and moves a branch, so it is not a default to add helpfully.

Resolution only happens when no file is named; anything naming a file is passed
straight through to `xed`. `-w`/`--wait` is stripped, because waiting on Xcode
would block this session.

## When it fails

- **Several candidates listed.** It found more than one workspace or project and
  will not guess. Ask the user which one, then rerun with that path.
- **Nothing found.** There is no `.xcworkspace`, `.xcodeproj`, or `Package.swift`
  within three levels. Say so — do not create a project or widen the search by
  hand.
- **It noted the branch is behind its upstream.** Not a failure — the project
  opened. Repeat the note and stop. Do not `git pull`, `git fetch`, or offer
  to; updating the checkout is a separate decision, and `--pull` is how the
  user makes it.
- **It reported that `--pull` did not pull.** Dirty checkout, no upstream,
  unreachable remote, or a diverged branch — the project still opened. Repeat
  the reason and stop. Do not stash, commit, set an upstream, retry, or fall
  back to `git pull --rebase` or `git merge`. It fast-forwards or it declines.
- **No worktree has that branch checked out.** Say so and stop. Do not run
  `git worktree add`, check the branch out, or open a different branch —
  `--branch` opens what already exists, and creating one is the user's call.
- **`xed-open: command not found`.** It is not on `PATH`. Say so and point at
  `install.sh` from https://github.com/Kilo-Loco/xed. Do not reimplement it.
- **Command Line Tools error.** The active developer directory points at the CLT
  rather than Xcode. Relay the `xcode-select -s` fix it prints; do not run it
  yourself, since it needs the user's password.
