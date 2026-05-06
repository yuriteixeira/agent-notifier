load_tmux_context() {
  tmux_session=$(tmux_current_session_name)
  tmux_session_id=$(tmux_current_session_id)
  tmux_client_name=$(tmux_current_client_name)
  tmux_window_id=$(tmux_current_window_id)
  tmux_pane_id=$(tmux_current_pane_id)
}

tmux_focus_command() {
  if [ -n "${tmux_client_name:-}" ] && [ -n "${tmux_pane_id:-}" ]; then
    printf "switch-client -c '%s' -t '%s'" "$tmux_client_name" "$tmux_pane_id"
  elif [ -n "${tmux_pane_id:-}" ]; then
    printf "switch-client -t '%s'" "$tmux_pane_id"
  elif [ -n "${tmux_client_name:-}" ] && [ -n "${tmux_session_id:-}" ]; then
    printf "switch-client -c '%s' -t '%s'" "$tmux_client_name" "$tmux_session_id"
  elif [ -n "${tmux_session_id:-}" ]; then
    printf "switch-client -t '%s'" "$tmux_session_id"
  fi
}

tmux_current_session_name() {
  tmux_display_format '#S' | squash_ws
}

tmux_current_session_id() {
  tmux_display_format '#{session_id}'
}

tmux_current_client_name() {
  [ -n "${TMUX:-}" ] && have tmux || return 0
  tmux display-message -p '#{client_name}' 2>/dev/null | head -n 1
}

tmux_current_window_id() {
  tmux_display_format '#{window_id}'
}

tmux_current_pane_id() {
  tmux_display_format '#{pane_id}'
}

tmux_display_format() {
  format=$1
  [ -n "${TMUX:-}" ] && have tmux || return 0
  if [ -n "${TMUX_PANE:-}" ]; then
    tmux display-message -p -t "$TMUX_PANE" "$format" 2>/dev/null | head -n 1
  else
    tmux display-message -p "$format" 2>/dev/null | head -n 1
  fi
}

tmux_escape_format() {
  sed 's/#/##/g'
}
