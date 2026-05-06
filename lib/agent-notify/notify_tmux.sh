notify_tmux() {
  [ -n "${TMUX:-}" ] && have tmux || return 0

  tmux_message=$(printf '%s: %s' "$title" "$body")
  tmux_menu_title=$(printf '%s' "$title" | tmux_escape_format)
  tmux_menu_item=$(printf '%s' "$tmux_message" | limit_text 160 | tmux_escape_format)
  tmux_menu_command=$(tmux_focus_command)

  (
    if [ -n "$tmux_menu_command" ]; then
      tmux display-menu \
        -x C \
        -y C \
        -s 'bg=yellow,fg=black,bold' \
        -S 'bg=yellow,fg=black,bold' \
        -H 'bg=black,fg=yellow,bold' \
        -T "$tmux_menu_title" \
        "$tmux_menu_item" f "$tmux_menu_command" ||
        tmux display-message -d 8000 "#[bg=yellow,fg=black,bold] $tmux_menu_item #[default]" ||
        true
    else
      tmux display-message -d 8000 "#[bg=yellow,fg=black,bold] $tmux_menu_item #[default]" || true
    fi
  ) >/dev/null 2>&1 </dev/null &

  { printf '\a' >/dev/tty; } 2>/dev/null || true
}
