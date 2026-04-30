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

  for tool in bash sed tr awk head cat basename; do
    path=$(tool_path "$tool") || {
      printf 'missing required test tool: %s\n' "$tool" >&2
      return 1
    }
    ln -s "$path" "$TOOLBIN/$tool"
  done

  CASE_PATH="$MOCKBIN:$TOOLBIN"
  unset NTFY_TOPIC NTFY_SERVER NTFY_TOKEN AGENT_NOTIFY_NTFY_ENV TMUX
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

run_payload() {
  local input=$1
  shift
  printf '%s' "$input" |
    PATH="$CASE_PATH" \
    HOME="$HOME_DIR" \
    AGENT_NOTIFY_TEST_LOG="$LOG" \
    AGENT_NOTIFY_TEST_UNAME="${AGENT_NOTIFY_TEST_UNAME:-Linux}" \
    TMUX="${TMUX:-}" \
    NTFY_TOPIC="${NTFY_TOPIC:-}" \
    NTFY_SERVER="${NTFY_SERVER:-}" \
    NTFY_TOKEN="${NTFY_TOKEN:-}" \
    AGENT_NOTIFY_NTFY_ENV="${AGENT_NOTIFY_NTFY_ENV:-}" \
    "$SCRIPT" "$@"
}

run_fixture() {
  local fixture=$1
  shift
  PATH="$CASE_PATH" \
    HOME="$HOME_DIR" \
    AGENT_NOTIFY_TEST_LOG="$LOG" \
    AGENT_NOTIFY_TEST_UNAME="${AGENT_NOTIFY_TEST_UNAME:-Linux}" \
    TMUX="${TMUX:-}" \
    NTFY_TOPIC="${NTFY_TOPIC:-}" \
    NTFY_SERVER="${NTFY_SERVER:-}" \
    NTFY_TOKEN="${NTFY_TOKEN:-}" \
    AGENT_NOTIFY_NTFY_ENV="${AGENT_NOTIFY_NTFY_ENV:-}" \
    "$SCRIPT" "$@" <"$ROOT/test/fixtures/$fixture"
}

run_no_stdin() {
  PATH="$CASE_PATH" \
    HOME="$HOME_DIR" \
    AGENT_NOTIFY_TEST_LOG="$LOG" \
    AGENT_NOTIFY_TEST_UNAME="${AGENT_NOTIFY_TEST_UNAME:-Linux}" \
    TMUX="${TMUX:-}" \
    NTFY_TOPIC="${NTFY_TOPIC:-}" \
    NTFY_SERVER="${NTFY_SERVER:-}" \
    NTFY_TOKEN="${NTFY_TOKEN:-}" \
    AGENT_NOTIFY_NTFY_ENV="${AGENT_NOTIFY_NTFY_ENV:-}" \
    "$SCRIPT" "$@"
}

assert_log_contains() {
  local needle=$1
  if ! grep -F -- "$needle" "$LOG" >/dev/null 2>&1; then
    printf 'expected log to contain: %s\n' "$needle" >&2
    return 1
  fi
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
  mock_uname
  mock_record tmux

  run_payload '{"message":"waiting"}' --agent claude --event interaction || return 1
  assert_log_contains 'tmux'
  assert_log_contains 'display-message'
  assert_log_contains 'Claude Code needs input: waiting'
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

test_invalid_flags_fail() {
  new_case || return 1
  mock_uname

  if run_no_stdin --agent nope --event finished >/dev/null 2>&1; then
    printf 'invalid agent unexpectedly succeeded\n' >&2
    return 1
  fi
}

run_test 'macOS chooses osascript' test_macos_uses_osascript
run_test 'Linux chooses notify-send' test_linux_uses_notify_send
run_test 'missing OS backend exits successfully' test_missing_os_backend_exits_successfully
run_test 'tmux display is attempted when available' test_tmux_attempted_when_available
run_test 'tmux display is skipped when tmux is missing' test_tmux_skipped_when_command_missing
run_test 'ntfy is skipped without a topic' test_ntfy_skipped_without_topic
run_test 'ntfy uses dotfile fallback' test_ntfy_dotfile_fallback
run_test 'ntfy env config wins over dotfile' test_ntfy_env_wins_over_dotfile
run_test 'ntfy priorities match event type' test_ntfy_priorities
run_test 'Claude fixture produces expected notification' test_claude_fixture_title_body
run_test 'Codex fixture produces expected notification' test_codex_fixture_title_body
run_test 'Gemini fixture produces expected notification' test_gemini_fixture_title_body
run_test 'Codex legacy positional payload works' test_codex_legacy_positional_payload
run_test 'invalid flags fail' test_invalid_flags_fail

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
