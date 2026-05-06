#!/usr/bin/env bash

set -eu

usage() {
  cat <<'EOF'
Usage: ./uninstall.sh [--prefix DIR] [--bin-dir DIR]

Removes the installed agent-notifier script and support modules. Configuration
snippets in Claude, Codex, Gemini, or ntfy files must be removed manually.
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

lib_dir="$(dirname -- "$bin_dir")/lib/agent-notifier"

dest="$bin_dir/agent-notifier"

if [ -e "$dest" ] || [ -L "$dest" ]; then
  rm "$dest"
  echo "Removed $dest"
else
  echo "No installed script found at $dest"
fi

removed_modules=0
for module in bootstrap cli core notify notify_local notify_tmux notify_ntfy tmux; do
  module_path="$lib_dir/$module.sh"
  if [ -e "$module_path" ] || [ -L "$module_path" ]; then
    rm "$module_path"
    removed_modules=1
  fi
done

if rmdir "$lib_dir" 2>/dev/null; then
  echo "Removed support module directory $lib_dir"
elif [ "$removed_modules" -eq 1 ]; then
  echo "Removed support modules from $lib_dir"
else
  echo "No support modules found at $lib_dir"
fi

cat <<'EOF'

Manual cleanup reminders:
- Remove agent-notifier hook snippets from ~/.claude/settings.json.
- Remove agent-notifier hook snippets from ~/.codex/config.toml.
- Remove agent-notifier hook snippets from ~/.gemini/settings.json.
- Remove ~/.config/agent-notifier/ntfy.env if you no longer want ntfy settings.
EOF
