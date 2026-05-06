usage() {
  cat >&2 <<'EOF'
Usage: agent-notifier --agent claude|codex|gemini --event finished|interaction [payload-json]

Reads hook JSON from stdin by default. For Codex legacy notification commands,
the first positional JSON payload is also accepted.
EOF
}

fail_usage() {
  printf 'agent-notifier: %s\n' "$1" >&2
  usage
  exit 64
}

have() {
  command -v "$1" >/dev/null 2>&1
}

squash_ws() {
  tr '\r\n\t' '   ' | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//'
}

limit_text() {
  awk -v max="$1" '{
    if (length($0) > max) {
      print substr($0, 1, max - 3) "..."
    } else {
      print
    }
  }'
}

lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

markdown_to_plain() {
  sed -E '
    s/!\[([^][]*)\]\([^)]*\)/\1/g
    s/\[([^][]*)\]\([^)]*\)/\1/g
    s/```[[:alnum:]_+-]*[[:space:]]*/ /g
    s/```/ /g
    s/`([^`]*)`/\1/g
    s/~~([^~]*)~~/\1/g
    s/(^|[[:space:]])#{1,6}[[:space:]]+/\1/g
    s/(^|[[:space:]])>[[:space:]]+/\1/g
    s/(^|[[:space:]])[-+*][[:space:]]+/\1/g
    s/(^|[[:space:]])[0-9]+[.)][[:space:]]+/\1/g
    s/\*\*([^*]*)\*\*/\1/g
    s/\*([^*]*)\*/\1/g
  '
}

json_unescape() {
  sed 's/\\"/"/g; s/\\\\/\\/g; s/\\n/ /g; s/\\r/ /g; s/\\t/ /g'
}

json_string_value() {
  key=$1
  [ -n "${payload:-}" ] || return 0
  printf '%s' "$payload" |
    tr '\n' ' ' |
    sed -nE 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' |
    head -n 1 |
    json_unescape
}

first_json_value() {
  for key in "$@"; do
    value=$(json_string_value "$key")
    if [ -n "$value" ]; then
      printf '%s' "$value"
      return 0
    fi
  done
}

agent_label() {
  case "$1" in
    claude) printf 'Claude Code' ;;
    codex) printf 'Codex CLI' ;;
    gemini) printf 'Gemini CLI' ;;
  esac
}

event_from_payload() {
  hint=$(first_json_value hook_event_name hook-event-name notification_type notification-type event type reason)
  hint=$(lower "$hint")
  case "$hint" in
    *afteragent*|*complete*|*completed*|*finish*|*finished*|*stop*|*turn-complete*)
      printf 'finished'
      ;;
    *)
      printf 'interaction'
      ;;
  esac
}

normalize_agent() {
  case "$(lower "$1")" in
    claude|claude-code|claudecode) printf 'claude' ;;
    codex|codex-cli|codexcli) printf 'codex' ;;
    gemini|gemini-cli|geminicli) printf 'gemini' ;;
    *) return 1 ;;
  esac
}

title_for() {
  payload_title=$(first_json_value title)
  if [ -n "$payload_title" ]; then
    printf '%s' "$payload_title" | markdown_to_plain | squash_ws | limit_text 96
    return 0
  fi

  label=$(agent_label "$agent")
  case "$event" in
    finished) printf '%s finished' "$label" ;;
    interaction) printf '%s needs input' "$label" ;;
  esac
}

body_for() {
  message=$(first_json_value message last_assistant_message last-assistant-message description reason prompt summary)
  cwd=$(first_json_value cwd current_working_directory current-working-directory workspace_dir workspace-dir)

  if [ -n "$message" ] && [ -n "$cwd" ]; then
    body_text=$(printf '%s (%s)' "$message" "$cwd")
  elif [ -n "$message" ]; then
    body_text=$(printf '%s' "$message")
  elif [ -n "$cwd" ]; then
    body_text=$(printf 'Working directory: %s' "$cwd")
  else
    label=$(agent_label "$agent")
    case "$event" in
      finished) body_text=$(printf '%s finished a turn.' "$label") ;;
      interaction) body_text=$(printf '%s is waiting for user interaction.' "$label") ;;
    esac
  fi

  body_text=$(printf '%s' "$body_text" | markdown_to_plain | squash_ws)
  if [ -n "${tmux_session:-}" ]; then
    body_text=$(printf '[%s] %s' "$tmux_session" "$body_text")
  fi
  printf '%s' "$body_text" | limit_text 420
}
