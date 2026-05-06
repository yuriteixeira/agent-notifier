osascript_quote() {
  sed 's/\\/\\\\/g; s/"/\\"/g'
}

notify_local() {
  os=$(uname -s 2>/dev/null || printf 'unknown')
  case "$os" in
    Darwin)
      if have osascript; then
        escaped_title=$(printf '%s' "$title" | osascript_quote)
        escaped_body=$(printf '%s' "$body" | osascript_quote)
        osascript -e "display notification \"$escaped_body\" with title \"$escaped_title\"" >/dev/null 2>&1 || true
      fi
      ;;
    Linux)
      if have notify-send; then
        notify-send "$title" "$body" >/dev/null 2>&1 || true
      fi
      ;;
  esac
}
