#!/usr/bin/env bash

set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/bin/agent-notify"
ORIGINAL_PATH=$PATH
PASS_COUNT=0
FAIL_COUNT=0
TMP_ROOT=

cleanup() {
  if [ -n "${TMP_ROOT:-}" ] && [ -d "$TMP_ROOT" ]; then
    rm -rf "$TMP_ROOT"
  fi
}
trap cleanup EXIT

fail() {
  local name=$1
  printf 'not ok - %s\n' "$name"
  if [ -n "${LOG:-}" ] && [ -f "$LOG" ]; then
    printf '  log:\n'
    sed 's/^/  | /' "$LOG"
  fi
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

pass() {
  local name=$1
  printf 'ok - %s\n' "$name"
  PASS_COUNT=$((PASS_COUNT + 1))
}

run_test() {
  local test_name=$1
  shift
  if "$@"; then
    pass "$test_name"
  else
    fail "$test_name"
  fi
}

tool_path() {
  PATH=$ORIGINAL_PATH command -v "$1"
}

new_case() {
  local tool path
  cleanup
  TMP_ROOT=$(mktemp -d)
  MOCKBIN="$TMP_ROOT/mockbin"
  TOOLBIN="$TMP_ROOT/toolbin"
  HOME_DIR="$TMP_ROOT/home"
  LOG="$TMP_ROOT/log"
  mkdir -p "$MOCKBIN" "$TOOLBIN" "$HOME_DIR"
  : >"$LOG"

  for tool in bash sed tr awk head cat basename dirname readlink; do
    path=$(tool_path "$tool") || {
      printf 'missing required test tool: %s\n' "$tool" >&2
      return 1
    }
    ln -s "$path" "$TOOLBIN/$tool"
  done

  CASE_PATH="$MOCKBIN:$TOOLBIN"
  unset NTFY_TOPIC NTFY_SERVER NTFY_TOKEN AGENT_NOTIFY_NTFY_ENV TMUX TMUX_PANE AGENT_NOTIFY_TEST_TMUX_SESSION_NAME AGENT_NOTIFY_TEST_TMUX_SESSION_ID AGENT_NOTIFY_TEST_TMUX_CLIENT_NAME AGENT_NOTIFY_TEST_TMUX_WINDOW_ID AGENT_NOTIFY_TEST_TMUX_PANE_ID
  AGENT_NOTIFY_TEST_UNAME=Linux
}

mock_cmd() {
  local name=$1
  local body=$2
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' "$body"
  } >"$MOCKBIN/$name"
  chmod +x "$MOCKBIN/$name"
}

mock_uname() {
  mock_cmd uname 'printf "%s\n" "$AGENT_NOTIFY_TEST_UNAME"'
}

mock_record() {
  mock_cmd "$1" '{
  printf "%s" "$(basename "$0")"
  for arg in "$@"; do
    printf "\t%s" "$arg"
  done
  printf "\n"
} >> "$AGENT_NOTIFY_TEST_LOG"'
}

mock_tmux_session() {
  mock_cmd tmux '{
  printf "%s" "$(basename "$0")"
  for arg in "$@"; do
    printf "\t%s" "$arg"
  done
  printf "\n"
} >> "$AGENT_NOTIFY_TEST_LOG"

if [ "${1:-}" = "display-message" ] && [ "${2:-}" = "-p" ]; then
  format=${3:-}
  if [ "$format" = "-t" ]; then
    format=${5:-}
  fi
  case "$format" in
    "#S") printf "%s\n" "$AGENT_NOTIFY_TEST_TMUX_SESSION_NAME" ;;
    "#{session_id}") printf "%s\n" "$AGENT_NOTIFY_TEST_TMUX_SESSION_ID" ;;
    "#{client_name}") printf "%s\n" "$AGENT_NOTIFY_TEST_TMUX_CLIENT_NAME" ;;
    "#{window_id}") printf "%s\n" "$AGENT_NOTIFY_TEST_TMUX_WINDOW_ID" ;;
    "#{pane_id}") printf "%s\n" "$AGENT_NOTIFY_TEST_TMUX_PANE_ID" ;;
  esac
fi'
}

run_agent_notify_as() {
  local command_path=$1
  shift
  PATH="$CASE_PATH" \
    HOME="$HOME_DIR" \
    AGENT_NOTIFY_TEST_LOG="$LOG" \
    AGENT_NOTIFY_TEST_UNAME="${AGENT_NOTIFY_TEST_UNAME:-Linux}" \
    TMUX="${TMUX:-}" \
    TMUX_PANE="${TMUX_PANE:-}" \
    NTFY_TOPIC="${NTFY_TOPIC:-}" \
    NTFY_SERVER="${NTFY_SERVER:-}" \
    NTFY_TOKEN="${NTFY_TOKEN:-}" \
    AGENT_NOTIFY_NTFY_ENV="${AGENT_NOTIFY_NTFY_ENV:-}" \
    AGENT_NOTIFY_TEST_TMUX_SESSION_NAME="${AGENT_NOTIFY_TEST_TMUX_SESSION_NAME:-}" \
    AGENT_NOTIFY_TEST_TMUX_SESSION_ID="${AGENT_NOTIFY_TEST_TMUX_SESSION_ID:-}" \
    AGENT_NOTIFY_TEST_TMUX_CLIENT_NAME="${AGENT_NOTIFY_TEST_TMUX_CLIENT_NAME:-}" \
    AGENT_NOTIFY_TEST_TMUX_WINDOW_ID="${AGENT_NOTIFY_TEST_TMUX_WINDOW_ID:-}" \
    AGENT_NOTIFY_TEST_TMUX_PANE_ID="${AGENT_NOTIFY_TEST_TMUX_PANE_ID:-}" \
    "$command_path" "$@"
}

run_agent_notify() {
  run_agent_notify_as "$SCRIPT" "$@"
}

run_payload() {
  local input=$1
  shift
  printf '%s' "$input" | run_agent_notify "$@"
}

run_fixture() {
  local fixture=$1
  shift
  run_agent_notify "$@" <"$ROOT/test/fixtures/$fixture"
}

run_no_stdin() {
  run_agent_notify "$@"
}

assert_log_contains() {
  local needle=$1
  if ! grep -F -- "$needle" "$LOG" >/dev/null 2>&1; then
    printf 'expected log to contain: %s\n' "$needle" >&2
    return 1
  fi
}

wait_log_contains() {
  local needle=$1
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if grep -F -- "$needle" "$LOG" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done

  printf 'expected log to contain: %s\n' "$needle" >&2
  return 1
}

assert_log_not_contains() {
  local needle=$1
  if grep -F -- "$needle" "$LOG" >/dev/null 2>&1; then
    printf 'expected log not to contain: %s\n' "$needle" >&2
    return 1
  fi
}

assert_log_empty() {
  if [ -s "$LOG" ]; then
    printf 'expected empty log\n' >&2
    return 1
  fi
}

test_macos_uses_osascript() {
  new_case || return 1
  AGENT_NOTIFY_TEST_UNAME=Darwin
  mock_uname
  mock_record osascript
  mock_record notify-send

  run_payload '{}' --agent claude --event finished || return 1
  assert_log_contains 'osascript'
  assert_log_contains 'Claude Code finished'
  assert_log_not_contains 'notify-send'
}

test_linux_uses_notify_send() {
  new_case || return 1
  AGENT_NOTIFY_TEST_UNAME=Linux
  mock_uname
  mock_record osascript
  mock_record notify-send

  run_payload '{}' --agent codex --event interaction || return 1
  assert_log_contains 'notify-send'
  assert_log_contains 'Codex CLI needs input'
  assert_log_not_contains 'osascript'
}

test_missing_os_backend_exits_successfully() {
  new_case || return 1
  AGENT_NOTIFY_TEST_UNAME=Linux
  mock_uname

  run_payload '{}' --agent gemini --event finished || return 1
  assert_log_empty
}

test_tmux_attempted_when_available() {
  new_case || return 1
  AGENT_NOTIFY_TEST_UNAME=Linux
  TMUX=/tmp/tmux-session
  TMUX_PANE='%34'
  AGENT_NOTIFY_TEST_TMUX_SESSION_NAME=agent-work
  AGENT_NOTIFY_TEST_TMUX_SESSION_ID='$9'
  AGENT_NOTIFY_TEST_TMUX_CLIENT_NAME=/dev/ttys015
  AGENT_NOTIFY_TEST_TMUX_WINDOW_ID='@12'
  AGENT_NOTIFY_TEST_TMUX_PANE_ID='%34'
  mock_uname
  mock_tmux_session

  run_payload '{"message":"waiting"}' --agent claude --event interaction || return 1
  assert_log_contains 'tmux'
  assert_log_contains 'display-message	-p	-t	%34	#S' || return 1
  assert_log_contains 'display-message	-p	-t	%34	#{session_id}' || return 1
  assert_log_contains 'display-message	-p	#{client_name}' || return 1
  assert_log_contains 'display-message	-p	-t	%34	#{window_id}' || return 1
  assert_log_contains 'display-message	-p	-t	%34	#{pane_id}' || return 1
  wait_log_contains 'display-menu' || return 1
  assert_log_contains '-x	C' || return 1
  assert_log_contains '-y	C' || return 1
  assert_log_contains 'bg=yellow,fg=black,bold' || return 1
  assert_log_contains 'Claude Code needs input: [agent-work] waiting' || return 1
  assert_log_contains '	f	' || return 1
  assert_log_contains "switch-client -c '/dev/ttys015' -t '%34'"
}

test_tmux_session_added_to_local_notification() {
  new_case || return 1
  AGENT_NOTIFY_TEST_UNAME=Linux
  TMUX=/tmp/tmux-session
  TMUX_PANE='%34'
  AGENT_NOTIFY_TEST_TMUX_SESSION_NAME=agent-work
  AGENT_NOTIFY_TEST_TMUX_SESSION_ID='$9'
  AGENT_NOTIFY_TEST_TMUX_CLIENT_NAME=/dev/ttys015
  AGENT_NOTIFY_TEST_TMUX_WINDOW_ID='@12'
  AGENT_NOTIFY_TEST_TMUX_PANE_ID='%34'
  mock_uname
  mock_tmux_session
  mock_record notify-send

  run_payload '{"message":"done"}' --agent codex --event finished || return 1
  assert_log_contains 'notify-send' || return 1
  assert_log_contains '[agent-work] done'
}

test_tmux_skipped_when_command_missing() {
  new_case || return 1
  AGENT_NOTIFY_TEST_UNAME=Linux
  TMUX=/tmp/tmux-session
  mock_uname

  run_payload '{"message":"waiting"}' --agent claude --event interaction || return 1
  assert_log_empty
}

test_ntfy_skipped_without_topic() {
  new_case || return 1
  AGENT_NOTIFY_TEST_UNAME=Linux
  mock_uname
  mock_record curl

  run_payload '{"message":"done"}' --agent codex --event finished || return 1
  assert_log_empty
}

test_ntfy_dotfile_fallback() {
  new_case || return 1
  AGENT_NOTIFY_TEST_UNAME=Linux
  mock_uname
  mock_record curl
  mkdir -p "$HOME_DIR/.config/agent-notify"
  {
    printf '%s\n' 'NTFY_TOPIC=file-topic'
    printf '%s\n' 'NTFY_SERVER=https://ntfy.example'
  } >"$HOME_DIR/.config/agent-notify/ntfy.env"

  run_payload '{"message":"done"}' --agent codex --event finished || return 1
  assert_log_contains 'https://ntfy.example/file-topic'
  assert_log_contains '--connect-timeout	2' || return 1
  assert_log_contains '--max-time	3'
}

test_ntfy_env_wins_over_dotfile() {
  new_case || return 1
  AGENT_NOTIFY_TEST_UNAME=Linux
  NTFY_TOPIC=env-topic
  NTFY_SERVER=https://env.example
  mock_uname
  mock_record curl
  mkdir -p "$HOME_DIR/.config/agent-notify"
  {
    printf '%s\n' 'NTFY_TOPIC=file-topic'
    printf '%s\n' 'NTFY_SERVER=https://file.example'
  } >"$HOME_DIR/.config/agent-notify/ntfy.env"

  run_payload '{"message":"done"}' --agent codex --event finished || return 1
  assert_log_contains 'https://env.example/env-topic'
  assert_log_not_contains 'file-topic'
}

test_ntfy_priorities() {
  new_case || return 1
  AGENT_NOTIFY_TEST_UNAME=Linux
  NTFY_TOPIC=topic
  mock_uname
  mock_record curl

  run_payload '{"message":"approval"}' --agent codex --event interaction || return 1
  assert_log_contains 'Priority: high' || return 1

  : >"$LOG"
  run_payload '{"message":"done"}' --agent codex --event finished || return 1
  assert_log_contains 'Priority: default'
}

test_claude_fixture_title_body() {
  new_case || return 1
  AGENT_NOTIFY_TEST_UNAME=Darwin
  mock_uname
  mock_record osascript

  run_fixture claude-finished.json --agent claude --event finished || return 1
  assert_log_contains 'Claude Code finished' || return 1
  assert_log_contains 'Implemented notifier and ran tests.'
}

test_codex_fixture_title_body() {
  new_case || return 1
  AGENT_NOTIFY_TEST_UNAME=Linux
  mock_uname
  mock_record notify-send

  run_fixture codex-interaction.json --agent codex --event interaction || return 1
  assert_log_contains 'Codex CLI needs input' || return 1
  assert_log_contains 'Approval required for make deploy'
}

test_gemini_fixture_title_body() {
  new_case || return 1
  AGENT_NOTIFY_TEST_UNAME=Darwin
  mock_uname
  mock_record osascript

  run_fixture gemini-finished.json --agent gemini --event finished || return 1
  assert_log_contains 'Gemini CLI finished' || return 1
  assert_log_contains 'Gemini finished the requested change.'
}

test_codex_legacy_positional_payload() {
  new_case || return 1
  AGENT_NOTIFY_TEST_UNAME=Linux
  mock_uname
  mock_record notify-send

  run_no_stdin '{"notification_type":"agent-turn-complete","message":"Legacy complete"}' || return 1
  assert_log_contains 'Codex CLI finished' || return 1
  assert_log_contains 'Legacy complete'
}

test_markdown_payload_becomes_plain_text() {
  new_case || return 1
  AGENT_NOTIFY_TEST_UNAME=Linux
  mock_uname
  mock_record notify-send

  run_payload '{"title":"**Build** `done`","message":"### Summary\n- Updated `bin/agent-notify`\n- See [README](https://example.test/readme)","cwd":"/tmp/project"}' --agent codex --event finished || return 1
  assert_log_contains 'Build done' || return 1
  assert_log_contains 'Summary Updated bin/agent-notify See README (/tmp/project)' || return 1
  assert_log_not_contains '**Build**' || return 1
  assert_log_not_contains '[README](https://example.test/readme)'
}

test_invalid_flags_fail() {
  new_case || return 1
  mock_uname

  if run_no_stdin --agent nope --event finished >/dev/null 2>&1; then
    printf 'invalid agent unexpectedly succeeded\n' >&2
    return 1
  fi
}

test_symlinked_script_uses_source_modules() {
  new_case || return 1
  AGENT_NOTIFY_TEST_UNAME=Linux
  mock_uname
  mock_record notify-send
  ln -s "$SCRIPT" "$TMP_ROOT/agent-notify"

  printf '{}' | run_agent_notify_as "$TMP_ROOT/agent-notify" --agent codex --event finished || return 1
  assert_log_contains 'notify-send' || return 1
  assert_log_contains 'Codex CLI finished'
}

run_test 'macOS chooses osascript' test_macos_uses_osascript
run_test 'Linux chooses notify-send' test_linux_uses_notify_send
run_test 'missing OS backend exits successfully' test_missing_os_backend_exits_successfully
run_test 'tmux display is attempted when available' test_tmux_attempted_when_available
run_test 'tmux session is added to local notifications' test_tmux_session_added_to_local_notification
run_test 'tmux display is skipped when tmux is missing' test_tmux_skipped_when_command_missing
run_test 'ntfy is skipped without a topic' test_ntfy_skipped_without_topic
run_test 'ntfy uses dotfile fallback' test_ntfy_dotfile_fallback
run_test 'ntfy env config wins over dotfile' test_ntfy_env_wins_over_dotfile
run_test 'ntfy priorities match event type' test_ntfy_priorities
run_test 'Claude fixture produces expected notification' test_claude_fixture_title_body
run_test 'Codex fixture produces expected notification' test_codex_fixture_title_body
run_test 'Gemini fixture produces expected notification' test_gemini_fixture_title_body
run_test 'Codex legacy positional payload works' test_codex_legacy_positional_payload
run_test 'Markdown payloads become plain text' test_markdown_payload_becomes_plain_text
run_test 'invalid flags fail' test_invalid_flags_fail
run_test 'symlinked script uses source modules' test_symlinked_script_uses_source_modules

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
