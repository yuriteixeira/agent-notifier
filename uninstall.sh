#!/usr/bin/env bash

set -eu

usage() {
  cat <<'EOF'
Usage: ./uninstall.sh [--prefix DIR] [--bin-dir DIR]

Removes the installed agent-notify script. Configuration snippets in Claude,
Codex, Gemini, or ntfy files must be removed manually.
EOF
}

prefix=${PREFIX:-"$HOME/.local"}
bin_dir=

while [ "$#" -gt 0 ]; do
  case "$1" in
    --prefix)
      [ "$#" -ge 2 ] || { echo "uninstall.sh: --prefix requires a value" >&2; exit 64; }
      prefix=$2
      shift 2
      ;;
    --bin-dir)
      [ "$#" -ge 2 ] || { echo "uninstall.sh: --bin-dir requires a value" >&2; exit 64; }
      bin_dir=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "uninstall.sh: unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

if [ -z "$bin_dir" ]; then
  bin_dir="$prefix/bin"
fi

dest="$bin_dir/agent-notify"

if [ -e "$dest" ] || [ -L "$dest" ]; then
  rm "$dest"
  echo "Removed $dest"
else
  echo "No installed script found at $dest"
fi

cat <<'EOF'

Manual cleanup reminders:
- Remove agent-notify hook snippets from ~/.claude/settings.json.
- Remove agent-notify hook snippets from ~/.codex/config.toml.
- Remove agent-notify hook snippets from ~/.gemini/settings.json.
- Remove ~/.config/agent-notify/ntfy.env if you no longer want ntfy settings.
EOF
