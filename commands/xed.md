---
description: "Open the current project in Xcode, like `xed` in the terminal"
argument-hint: "[dir|file...] [-l <line>] [-b] [-c]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/xed-open.sh:*)"]
---

# xed

Open the project in Xcode:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/xed-open.sh" $ARGUMENTS
```

The script above has already run. Report its outcome in one line — nothing more.

- It printed `Opened <target> in Xcode.` — say that, and stop. Do not summarize
  the project, read files, or offer next steps.
- It failed — relay the error verbatim. If it listed several candidates, ask
  which one to open; otherwise stop, do not try to fix the project.
- `${CLAUDE_PLUGIN_ROOT}` came through unsubstituted — report that the plugin is
  not installed correctly rather than guessing at a path.
