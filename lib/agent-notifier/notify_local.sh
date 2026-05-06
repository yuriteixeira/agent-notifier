notify_local() {
  case "$(local_os_name)" in
    Darwin) notify_macos ;;
    Linux) notify_linux ;;
  esac
}

notify_macos() {
  have osascript || return 0

  escaped_title=$(printf '%s' "$title" | osascript_quote)
  escaped_body=$(printf '%s' "$body" | osascript_quote)
  osascript -e "display notification \"$escaped_body\" with title \"$escaped_title\"" >/dev/null 2>&1 || true
}

notify_linux() {
  have notify-send || return 0

  notify-send "$title" "$body" >/dev/null 2>&1 || true
}

local_os_name() {
  uname -s 2>/dev/null || printf 'unknown'
}

osascript_quote() {
  sed 's/\\/\\\\/g; s/"/\\"/g'
}
