# xed

Open the project you're working on in Xcode, from whatever coding agent you're
working in.

It's the terminal `xed` you already know, with one addition: it figures out
*what* to open. `xed .` hands the directory to Xcode and hopes for the best.
This looks for the closest `.xcworkspace`, falls back to `.xcodeproj`, then to
`Package.swift`, and opens that.

```
/xed
Opened ./Xtraktr.xcworkspace in Xcode.
```

The whole thing is one dependency-free bash script — [`bin/xed-open`](bin/xed-open).
Everything else in this repo is a thin wrapper that teaches one agent to call
it. If your agent can run a shell command, it can use this.

Requires macOS with Xcode installed (not just the Command Line Tools).

## Install

### Any agent

Put the script on your `PATH`:

```bash
git clone https://github.com/Kilo-Loco/xed.git && ./xed/install.sh
```

Then `xed-open` works in any agent's terminal, and in your own. That's the whole
integration — the wrappers below just save you from typing it.

### Claude Code

```
/plugin marketplace add Kilo-Loco/xed
/plugin install xed@xed
```

Self-contained, so it doesn't need `install.sh` or anything on your `PATH`.
Restart Claude Code and `/xed` is there.

### Codex CLI

```bash
./install.sh --codex
```

That installs both forms, since which one your version supports differs:

- `~/.codex/prompts/xed.md` → invoke as `/prompts:xed`. Honors `CODEX_HOME`.
  OpenAI has deprecated custom prompts in favor of skills.
- `~/.agents/skills/xed/SKILL.md` → invoke as `$xed`, or let Codex trigger it
  when you ask to open something in Xcode. Note this is `~/.agents/`, not
  `~/.codex/` — skill discovery uses the shared `.agents/skills` convention and
  ignores `CODEX_HOME`. Override the location with `XED_SKILLS_DIR` if you need
  to; check it into `.agents/skills/` in a repo to share it with a team.

Restart Codex afterward. Both call `xed-open`, so `install.sh` must have put it
on your `PATH`.

## Usage

| Command | What happens |
| --- | --- |
| `xed-open` | Resolves the best target in the current directory and opens it |
| `xed-open SomeDir` | Same, but resolves inside `SomeDir` |
| `xed-open Sources/App.swift` | Opens that file — no resolution, passed to `xed` |
| `xed-open -l 42 Sources/App.swift` | Opens the file and jumps to line 42 |
| `xed-open -b` | Opens the resolved target but leaves Xcode in the background |
| `xed-open -p App.xcodeproj File.swift` | Straight passthrough to `xed` |

Every flag `xed(1)` supports — `-c`, `-b`, `-l`, `-p` — works. Resolution only
kicks in when you didn't name a file yourself.

The one exception is `-w`/`--wait`, which is stripped (with a note on stderr).
It tells `xed` to block until the file is closed in Xcode, which is useful as a
shell primitive but would hang the agent session that invoked it. Use `xed -w`
directly in a terminal if you need that.

## How the target is chosen

Searching outward from the directory you gave it, up to three levels deep:

1. **Shallowest wins.** A project at the repo root beats a workspace buried in a
   subdirectory.
2. **Within one level, workspace beats project beats package.** This is the
   CocoaPods and Tuist case, where opening the `.xcodeproj` is the wrong answer
   and silently gives you a target that won't build.
3. **`Foo.xcodeproj/project.xcworkspace` is never a candidate.** Neither is
   anything under `.git`, `.build`, `DerivedData`, `Pods`, `Carthage`,
   `node_modules`, or `.swiftpm`.
4. **Ties break on name.** Two workspaces in `MyApp/`? `MyApp.xcworkspace` wins.
   No name match, and it lists what it found and asks instead of guessing.

If nothing turns up, it says so rather than opening an empty Xcode window.

## Layout

```
bin/xed-open              the script — this is the actual product
install.sh                puts it on PATH, installs agent files
integrations/codex/       Codex CLI prompt + skill
commands/xed.md           Claude Code command
.claude-plugin/           Claude Code plugin + marketplace manifests
```

Claude Code's two directories sit at the repo root rather than under
`integrations/` because `/plugin marketplace add` looks for them there. That's a
mechanical requirement of its plugin loader, not a statement about which agent
matters.

## Adding another agent

Wrappers are thin on purpose — a wrapper's whole job is to run `xed-open` and
report one line back. [`integrations/codex/`](integrations/codex) is the
template: a prompt file for agents that only take instructions, and a skill file
for agents that can trigger on intent.

Two things are worth getting right, and both are visible in the existing
wrappers:

- **Tell the agent to stop after reporting.** Left to its own judgment, an agent
  that just opened a project will often start reading it.
- **Say what to do when it fails.** Without that, `command not found` becomes an
  agent that reimplements the resolution logic inline, badly.

If your agent supports shell pre-execution — Claude Code's ` ```! `, Gemini
CLI's `!{...}`, OpenCode's `` !`…` `` — use it. Xcode opens immediately instead of
after a round trip through the model.

PRs for other agents are welcome.

## License

MIT © Kilo Loco
