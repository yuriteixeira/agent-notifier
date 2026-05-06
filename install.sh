#!/usr/bin/env bash

set -eu

main() {
  parse_args "$@"
  set_install_paths
  set_source_paths
  verify_sources
  prepare_install_parent_dirs
  install_agent_notifier
  verify_installed_script
  prepare_printed_paths
  print_install_summary
  print_hook_snippets
}

parse_args() {
  mode=copy
  prefix=${PREFIX:-"$HOME/.local"}
  bin_dir=

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --copy)
        mode=copy
        shift
        ;;
      --symlink)
        mode=symlink
        shift
        ;;
      --prefix)
        [ "$#" -ge 2 ] || { echo "install.sh: --prefix requires a value" >&2; exit 64; }
        prefix=$2
        shift 2
        ;;
      --bin-dir)
        [ "$#" -ge 2 ] || { echo "install.sh: --bin-dir requires a value" >&2; exit 64; }
        bin_dir=$2
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "install.sh: unknown argument: $1" >&2
        usage >&2
        exit 64
        ;;
    esac
  done
}

set_install_paths() {
  if [ -z "$bin_dir" ]; then
    bin_dir="$prefix/bin"
  fi

  lib_dir="$(dirname -- "$bin_dir")/lib/agent-notifier"
  lib_parent_dir=$(dirname -- "$lib_dir")
  dest="$bin_dir/agent-notifier"
}

set_source_paths() {
  script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
  src="$script_dir/bin/agent-notifier"
  src_lib_dir="$script_dir/lib/agent-notifier"
}

verify_sources() {
  if [ ! -f "$src" ]; then
    echo "install.sh: missing $src" >&2
    exit 1
  fi

  if [ ! -d "$src_lib_dir" ]; then
    echo "install.sh: missing $src_lib_dir" >&2
    exit 1
  fi
}

prepare_install_parent_dirs() {
  mkdir -p "$bin_dir" "$lib_parent_dir"
}

install_agent_notifier() {
  case "$mode" in
    copy) install_copy ;;
    symlink) install_symlink ;;
  esac

  chmod +x "$dest"
}

install_copy() {
  prepare_copy_lib_dir
  remove_dest
  cp "$src" "$dest"
  cp "$src_lib_dir"/*.sh "$lib_dir"/
}

install_symlink() {
  prepare_symlink_lib_dir
  remove_dest
  ln -s "$src" "$dest"
}

verify_installed_script() {
  if ! "$dest" --help >/dev/null 2>&1; then
    echo "install.sh: installed script did not pass a basic smoke check" >&2
    exit 1
  fi
}

prepare_printed_paths() {
  snippet_dest=$(snippet_path "$dest")
  display_dest=$(display_path "$dest")
  display_lib_dir=$(display_path "$lib_dir")
}

print_install_summary() {
  echo "Installed $display_dest"
  echo "Installed support modules in $display_lib_dir"
  case ":$PATH:" in
    *":$bin_dir:"*) ;;
    *)
      echo
      echo "Note: $(display_path "$bin_dir") is not currently on PATH. The snippets below include the command path."
      ;;
  esac
}

print_hook_snippets() {
  cat <<EOF

Claude Code (~/.claude/settings.json)

{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$(json_command claude finished)",
            "async": true
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "$(json_command claude interaction)",
            "async": true
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$(json_command claude interaction)",
            "async": true
          }
        ]
      }
    ],
    "Elicitation": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$(json_command claude interaction)",
            "async": true
          }
        ]
      }
    ],
    "TeammateIdle": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$(json_command claude interaction)",
            "async": true
          }
        ]
      }
    ]
  }
}

Codex CLI (~/.codex/config.toml)

[features]
codex_hooks = true

[tui]
notifications = true
notification_condition = "always"
notification_method = "auto"

[[hooks.Stop]]
[[hooks.Stop.hooks]]
type = "command"
command = '$(toml_command codex finished)'
timeout = 5
statusMessage = "Sending notification"

[[hooks.PermissionRequest]]
matcher = "*"
[[hooks.PermissionRequest.hooks]]
type = "command"
command = '$(toml_command codex interaction)'
timeout = 5
statusMessage = "Sending notification"

Gemini CLI (~/.gemini/settings.json)

{
  "general": {
    "enableNotifications": true,
    "notificationMethod": "auto"
  },
  "hooks": {
    "AfterAgent": [
      {
        "matcher": "*",
        "hooks": [
          {
            "name": "agent-notifier-finished",
            "type": "command",
            "command": "$(json_command gemini finished)"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "*",
        "hooks": [
          {
            "name": "agent-notifier-interaction",
            "type": "command",
            "command": "$(json_command gemini interaction)"
          }
        ]
      }
    ]
  }
}

Optional ntfy setup

mkdir -p ~/.config/agent-notifier
cat > ~/.config/agent-notifier/ntfy.env <<'NTFY'
NTFY_TOPIC=replace-with-a-long-random-private-topic
NTFY_SERVER=https://ntfy.sh
# NTFY_TOKEN=optional-access-token
NTFY

Use an unpredictable ntfy topic name. Anyone who knows the topic can subscribe
unless your ntfy server enforces authentication.
EOF
}

prepare_copy_lib_dir() {
  if [ -L "$lib_dir" ]; then
    rm "$lib_dir"
  elif [ -e "$lib_dir" ] && [ ! -d "$lib_dir" ]; then
    echo "install.sh: $lib_dir exists and is not a directory" >&2
    exit 1
  fi

  mkdir -p "$lib_dir"
  remove_known_modules
}

prepare_symlink_lib_dir() {
  if [ -L "$lib_dir" ]; then
    rm "$lib_dir"
  elif [ -d "$lib_dir" ]; then
    remove_known_modules
    if ! rmdir "$lib_dir" 2>/dev/null; then
      echo "install.sh: $lib_dir contains files not installed by agent-notifier; remove them or use --copy" >&2
      exit 1
    fi
  elif [ -e "$lib_dir" ]; then
    echo "install.sh: $lib_dir exists and is not a directory or symlink" >&2
    exit 1
  fi

  ln -s "$src_lib_dir" "$lib_dir"
}

remove_known_modules() {
  [ -d "$lib_dir" ] || return 0

  for module in "$src_lib_dir"/*.sh; do
    module_dest="$lib_dir/$(basename -- "$module")"
    if [ -e "$module_dest" ] || [ -L "$module_dest" ]; then
      rm "$module_dest"
    fi
  done
}

remove_dest() {
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    rm "$dest"
  fi
}

snippet_path() {
  case "$1" in
    "$HOME"/*) printf '$HOME/%s' "${1#"$HOME"/}" ;;
    *) printf '%s' "$1" ;;
  esac
}

display_path() {
  case "$1" in
    "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;;
    "$HOME") printf '~' ;;
    *) printf '%s' "$1" ;;
  esac
}

json_command() {
  printf '\\"%s\\" --agent %s --event %s' "$snippet_dest" "$1" "$2"
}

toml_command() {
  printf '"%s" --agent %s --event %s' "$snippet_dest" "$1" "$2"
}

usage() {
  cat <<'EOF'
Usage: ./install.sh [--copy|--symlink] [--prefix DIR] [--bin-dir DIR]

Installs bin/agent-notifier and support modules under ~/.local by default, then
prints configuration snippets for Claude Code, Codex CLI, and Gemini CLI.
EOF
}

main "$@"
