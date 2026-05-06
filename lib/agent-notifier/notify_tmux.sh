notify_tmux() {
  [ -n "${TMUX:-}" ] && have tmux || return 0

  tmux_show_notification_async
  tmux_ring_terminal_bell
}

tmux_show_notification_async() {
  (
    tmux_show_notification || true
  ) >/dev/null 2>&1 </dev/null &
}

tmux_show_notification() {
  tmux_display_menu || tmux_display_fallback_message
}

tmux_display_menu() {
  tmux_build_menu_args
  tmux display-menu \
    -x C \
    -y C \
    -s 'bg=yellow,fg=black,bold' \
    -S 'bg=yellow,fg=black,bold' \
    -H 'bg=black,fg=yellow,bold' \
    -T "$(tmux_menu_title)" \
    "${tmux_menu_args[@]}"
}

tmux_build_menu_args() {
  tmux_menu_args=()
  tmux_menu_command=$(tmux_focus_command)
  tmux_menu_has_action=0

  while IFS= read -r tmux_body_line; do
    tmux_add_body_menu_item "$tmux_body_line"
  done <<EOF
$(tmux_body_menu_lines)
EOF

  tmux_ensure_menu_has_item
}

tmux_add_body_menu_item() {
  tmux_menu_item=$(printf '%s' "$1" | tmux_escape_format)

  if tmux_menu_should_focus; then
    tmux_add_focus_menu_item "$tmux_menu_item"
  else
    tmux_add_readonly_menu_item "$tmux_menu_item"
  fi
}

tmux_menu_should_focus() {
  [ "$tmux_menu_has_action" -eq 0 ] && [ -n "$tmux_menu_command" ]
}

tmux_add_focus_menu_item() {
  tmux_menu_args+=("$(tmux_focus_menu_label "$1")" f "$tmux_menu_command")
  tmux_menu_has_action=1
}

tmux_add_readonly_menu_item() {
  tmux_menu_args+=("$(tmux_readonly_menu_label "$1")" "" "")
}

tmux_ensure_menu_has_item() {
  if [ "${#tmux_menu_args[@]}" -eq 0 ]; then
    tmux_add_readonly_menu_item ''
  fi
}

tmux_display_fallback_message() {
  tmux display-message -d 8000 "#[bg=yellow,fg=black,bold] $(tmux_fallback_message) #[default]"
}

tmux_ring_terminal_bell() {
  { printf '\a' >/dev/tty; } 2>/dev/null || true
}

tmux_menu_title() {
  printf '%s' "$title" | tmux_escape_format
}

tmux_body_menu_lines() {
  printf '%s' "$body" | tmux_wrap_body_lines
}

tmux_fallback_message() {
  printf '%s' "$body" | limit_text 160 | tmux_escape_format
}

tmux_focus_menu_label() {
  case "$1" in
    -*) printf ' %s' "$1" ;;
    *) printf '%s' "$1" ;;
  esac
}

tmux_readonly_menu_label() {
  printf -- '- %s' "$1"
}

tmux_wrap_body_lines() {
  limit_text 360 | awk -v width=72 '
    {
      text = $0
      while (length(text) > width) {
        cut = width
        for (i = width; i > 1; i--) {
          if (substr(text, i, 1) == " ") {
            cut = i - 1
            break
          }
        }

        line = substr(text, 1, cut)
        sub(/[[:space:]]+$/, "", line)
        print line

        text = substr(text, cut + 1)
        sub(/^[[:space:]]+/, "", text)
      }

      if (length(text) > 0) {
        print text
      }
    }
  '
}
