---
name: xed
description: "Open the current project — or the worktree on a given branch — in Xcode, like `xed` in the terminal, picking the right target instead of guessing"
argument-hint: "[dir|file...] [--branch <name>] [-l <line>] [-b] [-c]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/bin/xed-open:*)", "Bash(true)"]
disable-model-invocation: true
---

# xed

Open the project in Xcode:

```!
"${CLAUDE_PLUGIN_ROOT}/bin/xed-open" $ARGUMENTS || true
```

The `|| true` is load-bearing. A non-zero exit from an injected command aborts
the whole invocation before Claude sees any of this file, and `xed-open` exits
non-zero on the two cases that most need a considered response: an ambiguous
project and no project at all. Swallowing the status keeps those reaching the
instructions below. `Bash(true)` is pre-approved for the same reason — a
compound command must match a permission rule on each side of the `||`.

`disable-model-invocation` is set because the command above runs *before* Claude
reads this file. Left model-invocable, Claude judging this skill relevant would
launch Xcode as a side effect of that judgment. Opening an app is the user's
call, so this stays a `/xed` you type.

The script above has already run, and its output (including stderr) is inlined
here. Report the outcome in one line — nothing more.

- It printed `Opened <target> in Xcode.` — say that, and stop. Do not summarize
  the project, read files, or offer next steps.
- It listed several candidates — ask which one to open, then rerun with that
  path. Do not pick one yourself.
- It noted that the branch is behind its upstream — repeat the note alongside
  the "Opened ..." line and stop. Do not `git pull`, `git fetch`, or offer to.
  The project is open; whether to update it is a separate decision the user has
  not asked you to make.
- No worktree has the requested branch checked out — say so and stop. Do not run
  `git worktree add`, check the branch out, or open a different one. `--branch`
  opens a checkout that already exists; creating one is the user's call.
- It failed some other way — relay the error verbatim and stop. Do not try to
  fix the project, create one, or widen the search by hand.
- The command above ran against a literal CLAUDE_PLUGIN_ROOT placeholder
  instead of a real directory — report that the plugin is not installed
  correctly rather than guessing at a path. (That name is written bare on
  purpose: in the braced form it would be substituted here too, and a
  backslash does not prevent it.)
