#!/usr/bin/env bash
#
# test/run.sh — exercise bin/xed-open without launching Xcode.
#
# XED_BIN points at a stub that prints its arguments, so every path through
# resolution, argument parsing, and the git logic can be checked by asserting on
# output and exit status. Same dependencies as the script under test: bash, git,
# and the coreutils already on any Mac. Run it with `./test/run.sh`.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
XED_OPEN=$ROOT/bin/xed-open
TMP=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

# git in a fixture, with identity supplied so this works on a bare CI box.
g() { git -c user.email=test@test -c user.name=test -c commit.gpgsign=false "$@"; }

# run <dir> <arg>... — capture stdout+stderr and status from a run in <dir>.
run() {
	local dir=$1
	shift
	OUT=$(cd "$dir" && XED_BIN=$TMP/stub-xed "$XED_OPEN" "$@" 2>&1)
	STATUS=$?
}

ok() {
	PASS=$((PASS + 1))
	printf '  ok    %s\n' "$1"
}

no() {
	FAIL=$((FAIL + 1))
	printf '  FAIL  %s\n' "$1"
	printf '        status %s, output:\n' "$STATUS"
	printf '%s\n' "$OUT" | sed 's/^/          /'
}

# expect_out <label> <substring> — output contains it.
expect_out() {
	case "$OUT" in
	*"$2"*) ok "$1" ;;
	*) no "$1" ;;
	esac
}

# expect_fail <label> <substring> — nonzero status AND the substring.
expect_fail() {
	if [ "$STATUS" -eq 0 ]; then
		no "$1 (expected nonzero exit)"
		return
	fi
	expect_out "$1" "$2"
}

# expect_no <label> <substring> — output does NOT contain it.
expect_no() {
	case "$OUT" in
	*"$2"*) no "$1" ;;
	*) ok "$1" ;;
	esac
}

printf '#!/usr/bin/env bash\nprintf "STUB: %%s\\n" "$*"\n' >"$TMP/stub-xed"
chmod +x "$TMP/stub-xed"

# --- fixture: a remote, a clone on main, a feature worktree, a bystander clone
# used to push commits the clone has not seen. ---------------------------------
git init -q --bare "$TMP/remote.git"
git clone -q "$TMP/remote.git" "$TMP/main" 2>/dev/null
(
	cd "$TMP/main" || exit 1
	git symbolic-ref HEAD refs/heads/main
	mkdir -p App.xcodeproj
	echo x >App.xcodeproj/x
	echo v1 >file.swift
	g add -A && g commit -qm init && git push -q -u origin main
	git worktree add -q ../feat -b feature/a
)
git clone -q "$TMP/remote.git" "$TMP/bystander"

# advance <n> — push <n> new commits to the remote from the bystander clone.
advance() {
	local i
	(
		cd "$TMP/bystander" || exit 1
		git pull -q --ff-only
		for i in $(seq 1 "$1"); do
			echo "remote $i" >>file.swift
			g add -A && g commit -qm "remote $i"
		done
		git push -q origin main
	)
}

printf '\nresolution\n'
run "$TMP/main"
expect_out 'bare invocation resolves the project' 'Opened ./App.xcodeproj'
run "$TMP/main" .
expect_out 'explicit directory resolves' 'Opened ./App.xcodeproj'
run "$TMP/main" App.xcodeproj
expect_out 'a bundle is already the target' 'Opened App.xcodeproj'
run "$TMP/main" file.swift
expect_out 'a file passes through to xed' 'STUB: file.swift'
expect_no 'a file is not announced as opened' 'Opened'
run "$TMP/main" -l 42 file.swift
expect_out '-l passes through with its value' 'STUB: -l 42 file.swift'
run "$TMP/main" -p App.xcodeproj file.swift
expect_out '-p is a straight passthrough' 'STUB: -p App.xcodeproj file.swift'
run "$TMP/main" -w
expect_out '-w is stripped' 'ignoring -w'
mkdir -p "$TMP/empty"
run "$TMP/empty"
expect_fail 'nothing to open says so' 'no .xcworkspace'

printf '\n--branch\n'
run "$TMP/feat" --branch main
expect_out 'finds the main clone from a worktree' "$TMP/main/App.xcodeproj"
run "$TMP/main" --branch feature/a
expect_out 'finds a worktree from the main clone' "$TMP/feat/App.xcodeproj"
run "$TMP/feat" --branch=main
expect_out '--branch=value form' "$TMP/main/App.xcodeproj"
run "$TMP/feat" --branch main -b
expect_out 'flags still reach xed' "STUB: -b $TMP/main/App.xcodeproj"
run "$TMP/feat" --branch
expect_fail 'missing value' 'needs a branch name'
run "$TMP/feat" --branch ''
expect_fail 'empty value does not silently open the cwd' 'needs a branch name'
run "$TMP/feat" --branch=
expect_fail 'empty --branch= value' 'needs a branch name'
run "$TMP/feat" --branch nope
expect_fail 'unknown branch names the branch, not worktrees' 'no branch named'
(cd "$TMP/main" && git branch -q unchecked)
run "$TMP/feat" --branch unchecked
expect_fail 'existing branch with no worktree suggests worktree add' 'git worktree add'
run "$TMP/feat" --branch main .
expect_fail '--branch rejects a path' "can't be combined with a path"
run "$TMP/feat" -p App.xcodeproj --branch main
expect_fail '--branch rejects -p before it' 'mutually exclusive'
run "$TMP/feat" --branch main -p App.xcodeproj
expect_fail '--branch rejects -p after it' 'mutually exclusive'
run / --branch main
expect_fail 'outside a repository' 'not inside a git repository'

printf '\nbare branch name\n'
run "$TMP/main" feature/a
expect_fail 'points at the flag' '--branch feature/a'
run "$TMP/main" Nope.swift
expect_out 'a missing file is still xed’s problem' 'STUB: Nope.swift'
run "$TMP/main" unchecked
expect_out 'a branch with no worktree is not a hint' 'STUB: unchecked'

printf '\nstale worktree\n'
(cd "$TMP/main" && git worktree add -q ../gone -b throwaway && rm -rf "$TMP/gone")
run "$TMP/main" --branch throwaway
expect_fail 'names the stale entry' 'git worktree prune'
(cd "$TMP/main" && git worktree prune)

printf '\nbehind note\n'
advance 2
run "$TMP/feat" --branch main
expect_no 'silent until the refs are fetched' 'behind'
(cd "$TMP/main" && git fetch -q origin)
run "$TMP/feat" --branch main
expect_out 'notes the count once fetched' "is 2 commits behind origin/main"
expect_out 'and opens anyway' 'Opened'
run "$TMP/main" --branch feature/a
expect_no 'no upstream, no note' 'behind'

printf '\n--pull\n'
run "$TMP/feat" --branch main --pull
expect_out 'fast-forwards' 'pulled 2 commits into main'
run "$TMP/feat" --branch main --pull
expect_out 'already current' 'already up to date'
echo dirty >>"$TMP/main/file.swift"
advance 1
run "$TMP/feat" --branch main --pull
expect_out 'skips a dirty checkout' 'uncommitted changes'
expect_out 'and opens it anyway' 'Opened'
(cd "$TMP/main" && git checkout -q -- file.swift)
(
	cd "$TMP/main" || exit 1
	echo local >local.swift
	g add -A && g commit -qm "local only"
)
run "$TMP/feat" --branch main --pull
expect_out 'declines to reconcile a diverged branch' 'diverged'
expect_out 'and opens it anyway' 'Opened'
(cd "$TMP/main" && git reset -q --hard origin/main)
advance 1
run "$TMP/main" --pull
expect_out 'works without --branch, naming the branch' 'pulled 1 commit into main'
run "$TMP/feat" --pull
expect_out 'no upstream declines' 'not tracking a remote branch'
mkdir -p "$TMP/nogit/App.xcodeproj"
run "$TMP/nogit" --pull
expect_out 'a non-repo declines rather than dying' 'not in a git repository'
expect_out 'and still opens' 'Opened'
run "$TMP/main" --pull file.swift
expect_fail '--pull rejects a file' "can't be combined with a file"
run "$TMP/main" --pull . App.xcodeproj
expect_fail '--pull rejects two operands' 'at most one directory'
run "$TMP/main" -p App.xcodeproj --pull
expect_fail '--pull rejects -p' 'mutually exclusive'

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
