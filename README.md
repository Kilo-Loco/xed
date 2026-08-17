# xed

A Claude Code plugin that adds `/xed` — open the project you're working on in
Xcode, without leaving the session.

It's the terminal `xed` you already know, with one addition: it figures out
*what* to open. `xed .` hands the directory to Xcode and hopes for the best.
`/xed` looks for the closest `.xcworkspace`, falls back to `.xcodeproj`, then to
`Package.swift`, and opens that.

```
/xed
Opened ./Xtraktr.xcworkspace in Xcode.
```

## Install

```bash
claude
```

Then, in Claude Code:

```
/plugin marketplace add Kilo-Loco/xed
/plugin install xed@xed
```

Requires macOS with Xcode installed (not just the Command Line Tools).

## Usage

| Command | What happens |
| --- | --- |
| `/xed` | Resolves the best target in the current directory and opens it |
| `/xed SomeDir` | Same, but resolves inside `SomeDir` |
| `/xed Sources/App.swift` | Opens that file — no resolution, passed to `xed` |
| `/xed -l 42 Sources/App.swift` | Opens the file and jumps to line 42 |
| `/xed -b` | Opens the resolved target but leaves Xcode in the background |
| `/xed -p App.xcodeproj File.swift` | Straight passthrough to `xed` |

Every flag `xed(1)` supports — `-c`, `-b`, `-w`, `-l`, `-p` — works. Resolution
only kicks in when you didn't name a file yourself.

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

## Using the script without Claude Code

`scripts/xed-open.sh` is a standalone bash script with no dependencies beyond
`xed` itself. Alias it if you want the same resolution in your shell:

```bash
alias xd='~/path/to/xed/scripts/xed-open.sh'
```

## License

MIT © Kilo Loco
