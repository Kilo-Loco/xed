#!/usr/bin/env bash
#
# install.sh — put `xed-open` on your PATH, and optionally install the Codex CLI
# command files.
#
# Claude Code users do not need this: `/plugin marketplace add Kilo-Loco/xed`
# installs a self-contained copy. See the README.
#
# Usage:
#   ./install.sh                 link xed-open, plus any agent whose config
#                                directory already exists
#   ./install.sh --codex         link xed-open and install the Codex files
#   ./install.sh --bin-dir DIR   link into DIR instead of the default
#   ./install.sh --link-only     just put xed-open on PATH
#   ./install.sh --force         overwrite files that are already there
#   ./install.sh --dry-run       print what would happen, change nothing

set -o pipefail

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
BIN_DIR=${XED_BIN_DIR:-}
CODEX_HOME=${CODEX_HOME:-$HOME/.codex}

want_codex=auto
link_only=0
force=0
dry_run=0

say() { printf '%s\n' "$*"; }
die() {
	printf 'install.sh: %s\n' "$*" >&2
	exit 1
}

run() {
	if [ "$dry_run" -eq 1 ]; then
		printf '  would: %s\n' "$*"
	else
		"$@" || die "failed: $*"
	fi
}

# Outcome lines describe work that happened, so they stay quiet on a dry run
# rather than claiming credit for it.
result() { [ "$dry_run" -eq 1 ] || say "$@"; }

while [ $# -gt 0 ]; do
	case "$1" in
	--codex)
		want_codex=yes
		shift
		;;
	--link-only)
		link_only=1
		shift
		;;
	--force)
		force=1
		shift
		;;
	--dry-run)
		dry_run=1
		shift
		;;
	--bin-dir)
		[ $# -ge 2 ] || die "--bin-dir needs a directory."
		BIN_DIR=$2
		shift 2
		;;
	-h | --help)
		cat <<'EOF'
install.sh — put xed-open on your PATH, and optionally install the Codex CLI
command files. Claude Code users do not need this; see the README.

  --codex          install the Codex CLI files even if ~/.codex is absent
  --bin-dir DIR    link into DIR instead of the default
  --link-only      just put xed-open on PATH
  --force          overwrite files that are already there
  --dry-run        print what would happen, change nothing
EOF
		exit 0
		;;
	*) die "unknown option: $1 (try --help)" ;;
	esac
done

[ "$(uname -s)" = "Darwin" ] || die "xed only exists on macOS."
[ -x "$REPO_DIR/bin/xed-open" ] || die "can't find bin/xed-open next to this script."

# --- xed-open onto PATH -----------------------------------------------------
#
# Prefer a directory the user already has on PATH so nothing needs sudo. Falls
# back to creating ~/.local/bin, which is the conventional spot for this.
if [ -z "$BIN_DIR" ]; then
	for candidate in "$HOME/.local/bin" "$HOME/bin" /usr/local/bin; do
		case ":$PATH:" in
		*":$candidate:"*)
			[ -w "$candidate" ] && BIN_DIR=$candidate && break
			;;
		esac
	done
	[ -z "$BIN_DIR" ] && BIN_DIR="$HOME/.local/bin"
fi

say "Linking xed-open into $BIN_DIR"
[ -d "$BIN_DIR" ] || run mkdir -p "$BIN_DIR"

target=$BIN_DIR/xed-open
if [ -e "$target" ] || [ -L "$target" ]; then
	if [ "$(readlink "$target" 2>/dev/null)" = "$REPO_DIR/bin/xed-open" ]; then
		say "  already linked"
	elif [ "$force" -eq 1 ]; then
		run ln -sf "$REPO_DIR/bin/xed-open" "$target"
		result "  replaced"
	else
		die "$target already exists. Re-run with --force to replace it."
	fi
else
	run ln -s "$REPO_DIR/bin/xed-open" "$target"
	result "  linked"
fi

case ":$PATH:" in
*":$BIN_DIR:"*) ;;
*)
	say ""
	say "  Note: $BIN_DIR is not on your PATH. Add this to your shell profile:"
	say "    export PATH=\"$BIN_DIR:\$PATH\""
	;;
esac

# --- agent command files ----------------------------------------------------

# install_file <source> <destination> — copy unless something is already there.
install_file() {
	local src=$1 dest=$2
	if { [ -e "$dest" ] || [ -L "$dest" ]; } && [ "$force" -eq 0 ]; then
		say "  skipped $dest (already exists — use --force to replace)"
		return
	fi
	run mkdir -p "$(dirname "$dest")"
	run cp "$src" "$dest"
	result "  installed $dest"
}

if [ "$link_only" -eq 0 ]; then
	if [ "$want_codex" = "yes" ] || { [ "$want_codex" = "auto" ] && [ -d "$CODEX_HOME" ]; }; then
		say ""
		say "Installing Codex CLI files into $CODEX_HOME"
		install_file "$REPO_DIR/integrations/codex/prompts/xed.md" \
			"$CODEX_HOME/prompts/xed.md"
		install_file "$REPO_DIR/integrations/codex/skills/xed/SKILL.md" \
			"$CODEX_HOME/skills/xed/SKILL.md"
		say "  restart Codex to pick them up"
	elif [ "$want_codex" = "auto" ]; then
		say ""
		say "No $CODEX_HOME found — skipping Codex. Pass --codex to install anyway."
	fi
fi

say ""
say "Done. Run xed-open inside a project to try it."
