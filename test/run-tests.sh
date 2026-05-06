#!/usr/bin/env bash

set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/bin/agent-notifier"
ORIGINAL_PATH=$PATH
PASS_COUNT=0
FAIL_COUNT=0
TMP_ROOT=

main() {
  run_test 'macOS chooses osascript' test_macos_uses_osascript
  run_test 'Linux chooses notify-send' test_linux_uses_notify_send
  run_test 'missing OS backend exits successfully' test_missing_os_backend_exits_successfully
  run_test 'tmux display is attempted when available' test_tmux_attempted_when_available
  run_test 'tmux default body does not repeat title' test_tmux_default_body_does_not_repeat_title
  run_test 'tmux body wraps into multiple menu rows' test_tmux_body_wraps_into_multiple_menu_rows
  run_test 'tmux session is added to local notifications' test_tmux_session_added_to_local_notification
  run_test 'tmux display is skipped when tmux is missing' test_tmux_skipped_when_command_missing
  run_test 'ntfy is skipped without a topic' test_ntfy_skipped_without_topic
  run_test 'ntfy uses dotfile fallback' test_ntfy_dotfile_fallback
  run_test 'ntfy env config wins over dotfile' test_ntfy_env_wins_over_dotfile
  run_test 'ntfy priorities match event type' test_ntfy_priorities
  run_test 'Claude fixture produces expected notification' test_claude_fixture_title_body
  run_test 'Codex fixture produces expected notification' test_codex_fixture_title_body
  run_test 'Gemini fixture produces expected notification' test_gemini_fixture_title_body
  run_test 'Gemini notification fixture produces expected interaction' test_gemini_notification_fixture_title_body
  run_test 'Codex legacy positional payload works' test_codex_legacy_positional_payload
  run_test 'Markdown payloads become plain text' test_markdown_payload_becomes_plain_text
  run_test 'invalid flags fail' test_invalid_flags_fail
  run_test 'AGENT_NOTIFIER_LIB_DIR supports custom layouts' test_agent_notifier_lib_dir_override_allows_custom_layout
  run_test 'copy install runs from a temporary prefix' test_install_copy_runs_from_temp_prefix
  run_test 'symlink install links executable and module directory' test_install_symlink_links_executable_and_lib_dir
  run_test 'symlink install runs when bin directory is a symlink' test_install_symlink_runs_from_symlinked_bin_dir
  run_test 'symlink install replaces old module directories' test_install_symlink_replaces_old_module_directory
  run_test 'symlink install refuses unexpected lib contents' test_install_symlink_refuses_unexpected_lib_contents
  run_test 'uninstall removes installed bootstrap module' test_uninstall_removes_installed_bootstrap_module
  run_test 'uninstall removes symlinked module directory' test_uninstall_removes_symlinked_lib_directory

  printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
  [ "$FAIL_COUNT" -eq 0 ]
}

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
  unset NTFY_TOPIC NTFY_SERVER NTFY_TOKEN AGENT_NOTIFIER_NTFY_ENV AGENT_NOTIFIER_LIB_DIR TMUX TMUX_PANE AGENT_NOTIFIER_TEST_TMUX_SESSION_NAME AGENT_NOTIFIER_TEST_TMUX_SESSION_ID AGENT_NOTIFIER_TEST_TMUX_CLIENT_NAME AGENT_NOTIFIER_TEST_TMUX_WINDOW_ID AGENT_NOTIFIER_TEST_TMUX_PANE_ID
  AGENT_NOTIFIER_TEST_UNAME=Linux
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
  mock_cmd uname 'printf "%s\n" "$AGENT_NOTIFIER_TEST_UNAME"'
}

mock_record() {
  mock_cmd "$1" '{
  printf "%s" "$(basename "$0")"
  for arg in "$@"; do
    printf "\t%s" "$arg"
  done
  printf "\n"
} >> "$AGENT_NOTIFIER_TEST_LOG"'
}

mock_tmux_session() {
  mock_cmd tmux '{
  printf "%s" "$(basename "$0")"
  for arg in "$@"; do
    printf "\t%s" "$arg"
  done
  printf "\n"
} >> "$AGENT_NOTIFIER_TEST_LOG"

if [ "${1:-}" = "display-message" ] && [ "${2:-}" = "-p" ]; then
  format=${3:-}
  if [ "$format" = "-t" ]; then
    format=${5:-}
  fi
  case "$format" in
    "#S") printf "%s\n" "$AGENT_NOTIFIER_TEST_TMUX_SESSION_NAME" ;;
    "#{session_id}") printf "%s\n" "$AGENT_NOTIFIER_TEST_TMUX_SESSION_ID" ;;
    "#{client_name}") printf "%s\n" "$AGENT_NOTIFIER_TEST_TMUX_CLIENT_NAME" ;;
    "#{window_id}") printf "%s\n" "$AGENT_NOTIFIER_TEST_TMUX_WINDOW_ID" ;;
    "#{pane_id}") printf "%s\n" "$AGENT_NOTIFIER_TEST_TMUX_PANE_ID" ;;
  esac
fi'
}

run_agent_notifier_as() {
  local command_path=$1
  shift
  PATH="$CASE_PATH" \
    HOME="$HOME_DIR" \
    AGENT_NOTIFIER_TEST_LOG="$LOG" \
    AGENT_NOTIFIER_TEST_UNAME="${AGENT_NOTIFIER_TEST_UNAME:-Linux}" \
    TMUX="${TMUX:-}" \
    TMUX_PANE="${TMUX_PANE:-}" \
    NTFY_TOPIC="${NTFY_TOPIC:-}" \
    NTFY_SERVER="${NTFY_SERVER:-}" \
    NTFY_TOKEN="${NTFY_TOKEN:-}" \
    AGENT_NOTIFIER_NTFY_ENV="${AGENT_NOTIFIER_NTFY_ENV:-}" \
    AGENT_NOTIFIER_LIB_DIR="${AGENT_NOTIFIER_LIB_DIR:-}" \
    AGENT_NOTIFIER_TEST_TMUX_SESSION_NAME="${AGENT_NOTIFIER_TEST_TMUX_SESSION_NAME:-}" \
    AGENT_NOTIFIER_TEST_TMUX_SESSION_ID="${AGENT_NOTIFIER_TEST_TMUX_SESSION_ID:-}" \
    AGENT_NOTIFIER_TEST_TMUX_CLIENT_NAME="${AGENT_NOTIFIER_TEST_TMUX_CLIENT_NAME:-}" \
    AGENT_NOTIFIER_TEST_TMUX_WINDOW_ID="${AGENT_NOTIFIER_TEST_TMUX_WINDOW_ID:-}" \
    AGENT_NOTIFIER_TEST_TMUX_PANE_ID="${AGENT_NOTIFIER_TEST_TMUX_PANE_ID:-}" \
    "$command_path" "$@"
}

run_agent_notifier() {
  run_agent_notifier_as "$SCRIPT" "$@"
}

run_payload() {
  local input=$1
  shift
  printf '%s' "$input" | run_agent_notifier "$@"
}

run_fixture() {
  local fixture=$1
  shift
  run_agent_notifier "$@" <"$ROOT/test/fixtures/$fixture"
}

run_no_stdin() {
  run_agent_notifier "$@"
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
  AGENT_NOTIFIER_TEST_UNAME=Darwin
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
  AGENT_NOTIFIER_TEST_UNAME=Linux
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
  AGENT_NOTIFIER_TEST_UNAME=Linux
  mock_uname

  run_payload '{}' --agent gemini --event finished || return 1
  assert_log_empty
}

test_tmux_attempted_when_available() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Linux
  TMUX=/tmp/tmux-session
  TMUX_PANE='%34'
  AGENT_NOTIFIER_TEST_TMUX_SESSION_NAME=agent-work
  AGENT_NOTIFIER_TEST_TMUX_SESSION_ID='$9'
  AGENT_NOTIFIER_TEST_TMUX_CLIENT_NAME=/dev/ttys015
  AGENT_NOTIFIER_TEST_TMUX_WINDOW_ID='@12'
  AGENT_NOTIFIER_TEST_TMUX_PANE_ID='%34'
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
  assert_log_contains '-T	Claude Code needs input' || return 1
  assert_log_contains '[agent-work] waiting' || return 1
  assert_log_not_contains 'Claude Code needs input: [agent-work] waiting' || return 1
  assert_log_contains '	f	' || return 1
  assert_log_contains "switch-client -c '/dev/ttys015' -t '%34'"
}

test_tmux_default_body_does_not_repeat_title() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Linux
  TMUX=/tmp/tmux-session
  TMUX_PANE='%34'
  AGENT_NOTIFIER_TEST_TMUX_SESSION_NAME=agent-work
  AGENT_NOTIFIER_TEST_TMUX_SESSION_ID='$9'
  AGENT_NOTIFIER_TEST_TMUX_CLIENT_NAME=/dev/ttys015
  AGENT_NOTIFIER_TEST_TMUX_WINDOW_ID='@12'
  AGENT_NOTIFIER_TEST_TMUX_PANE_ID='%34'
  mock_uname
  mock_tmux_session

  run_payload '{}' --agent codex --event finished || return 1
  wait_log_contains 'display-menu' || return 1
  assert_log_contains '-T	Codex CLI finished' || return 1
  assert_log_contains '[agent-work] Finished a turn.' || return 1
  assert_log_not_contains 'Codex CLI finished: [agent-work]' || return 1
  assert_log_not_contains 'Codex CLI finished a turn.'
}

test_tmux_body_wraps_into_multiple_menu_rows() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Linux
  TMUX=/tmp/tmux-session
  TMUX_PANE='%34'
  AGENT_NOTIFIER_TEST_TMUX_SESSION_NAME=agent-work
  AGENT_NOTIFIER_TEST_TMUX_SESSION_ID='$9'
  AGENT_NOTIFIER_TEST_TMUX_CLIENT_NAME=/dev/ttys015
  AGENT_NOTIFIER_TEST_TMUX_WINDOW_ID='@12'
  AGENT_NOTIFIER_TEST_TMUX_PANE_ID='%34'
  mock_uname
  mock_tmux_session

  run_payload '{"message":"alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega"}' --agent codex --event finished || return 1
  wait_log_contains 'display-menu' || return 1
  assert_log_contains '[agent-work] alpha beta gamma delta epsilon zeta eta theta iota kappa' || return 1
  assert_log_contains '- lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega' || return 1
}

test_tmux_session_added_to_local_notification() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Linux
  TMUX=/tmp/tmux-session
  TMUX_PANE='%34'
  AGENT_NOTIFIER_TEST_TMUX_SESSION_NAME=agent-work
  AGENT_NOTIFIER_TEST_TMUX_SESSION_ID='$9'
  AGENT_NOTIFIER_TEST_TMUX_CLIENT_NAME=/dev/ttys015
  AGENT_NOTIFIER_TEST_TMUX_WINDOW_ID='@12'
  AGENT_NOTIFIER_TEST_TMUX_PANE_ID='%34'
  mock_uname
  mock_tmux_session
  mock_record notify-send

  run_payload '{"message":"done"}' --agent codex --event finished || return 1
  assert_log_contains 'notify-send' || return 1
  assert_log_contains '[agent-work] done'
}

test_tmux_skipped_when_command_missing() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Linux
  TMUX=/tmp/tmux-session
  mock_uname

  run_payload '{"message":"waiting"}' --agent claude --event interaction || return 1
  assert_log_empty
}

test_ntfy_skipped_without_topic() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Linux
  mock_uname
  mock_record curl

  run_payload '{"message":"done"}' --agent codex --event finished || return 1
  assert_log_empty
}

test_ntfy_dotfile_fallback() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Linux
  mock_uname
  mock_record curl
  mkdir -p "$HOME_DIR/.config/agent-notifier"
  {
    printf '%s\n' 'NTFY_TOPIC=file-topic'
    printf '%s\n' 'NTFY_SERVER=https://ntfy.example'
  } >"$HOME_DIR/.config/agent-notifier/ntfy.env"

  run_payload '{"message":"done"}' --agent codex --event finished || return 1
  assert_log_contains 'https://ntfy.example/file-topic'
  assert_log_contains '--connect-timeout	2' || return 1
  assert_log_contains '--max-time	3'
}

test_ntfy_env_wins_over_dotfile() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Linux
  NTFY_TOPIC=env-topic
  NTFY_SERVER=https://env.example
  mock_uname
  mock_record curl
  mkdir -p "$HOME_DIR/.config/agent-notifier"
  {
    printf '%s\n' 'NTFY_TOPIC=file-topic'
    printf '%s\n' 'NTFY_SERVER=https://file.example'
  } >"$HOME_DIR/.config/agent-notifier/ntfy.env"

  run_payload '{"message":"done"}' --agent codex --event finished || return 1
  assert_log_contains 'https://env.example/env-topic'
  assert_log_not_contains 'file-topic'
}

test_ntfy_priorities() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Linux
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
  AGENT_NOTIFIER_TEST_UNAME=Darwin
  mock_uname
  mock_record osascript

  run_fixture claude-finished.json --agent claude --event finished || return 1
  assert_log_contains 'Claude Code finished' || return 1
  assert_log_contains 'Implemented notifier and ran tests.'
}

test_codex_fixture_title_body() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Linux
  mock_uname
  mock_record notify-send

  run_fixture codex-interaction.json --agent codex --event interaction || return 1
  assert_log_contains 'Codex CLI needs input' || return 1
  assert_log_contains 'Approval required for make deploy'
}

test_gemini_fixture_title_body() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Darwin
  mock_uname
  mock_record osascript

  run_fixture gemini-finished.json --agent gemini --event finished || return 1
  assert_log_contains 'Gemini CLI finished' || return 1
  assert_log_contains 'Gemini finished the requested change.'
}

test_gemini_notification_fixture_title_body() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Darwin
  mock_uname
  mock_record osascript

  run_fixture gemini-notification.json --agent gemini --event interaction || return 1
  assert_log_contains 'Gemini CLI needs input' || return 1
  assert_log_contains 'Allow run_shell_command?'
}

test_codex_legacy_positional_payload() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Linux
  mock_uname
  mock_record notify-send

  run_no_stdin '{"notification_type":"agent-turn-complete","message":"Legacy complete"}' || return 1
  assert_log_contains 'Codex CLI finished' || return 1
  assert_log_contains 'Legacy complete'
}

test_markdown_payload_becomes_plain_text() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Linux
  mock_uname
  mock_record notify-send

  run_payload '{"title":"**Build** `done`","message":"### Summary\n- Updated `bin/agent-notifier`\n- See [README](https://example.test/readme)","cwd":"/tmp/project"}' --agent codex --event finished || return 1
  assert_log_contains 'Build done' || return 1
  assert_log_contains 'Summary Updated bin/agent-notifier See README (/tmp/project)' || return 1
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

test_agent_notifier_lib_dir_override_allows_custom_layout() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Linux
  AGENT_NOTIFIER_LIB_DIR="$ROOT/lib/agent-notifier"
  mock_uname
  mock_record notify-send
  ln -s "$SCRIPT" "$TMP_ROOT/agent-notifier"

  printf '{}' | run_agent_notifier_as "$TMP_ROOT/agent-notifier" --agent codex --event finished || return 1
  assert_log_contains 'notify-send' || return 1
  assert_log_contains 'Codex CLI finished'
}

test_install_copy_runs_from_temp_prefix() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Linux
  mock_uname
  mock_record notify-send
  install_prefix="$TMP_ROOT/prefix"

  PATH="$ORIGINAL_PATH" "$ROOT/install.sh" --prefix "$install_prefix" >"$TMP_ROOT/install.out" || return 1
  grep -F '"name": "agent-notifier-interaction"' "$TMP_ROOT/install.out" >/dev/null 2>&1 || {
    printf 'Gemini interaction hook is missing from install output\n' >&2
    return 1
  }
  grep -F -- '--agent gemini --event interaction' "$TMP_ROOT/install.out" >/dev/null 2>&1 || {
    printf 'Gemini interaction command is missing from install output\n' >&2
    return 1
  }

  [ -f "$install_prefix/bin/agent-notifier" ] || {
    printf 'installed executable is missing\n' >&2
    return 1
  }
  [ ! -L "$install_prefix/bin/agent-notifier" ] || {
    printf 'copy install unexpectedly created an executable symlink\n' >&2
    return 1
  }
  [ -d "$install_prefix/lib/agent-notifier" ] || {
    printf 'installed module directory is missing\n' >&2
    return 1
  }

  printf '{}' | run_agent_notifier_as "$install_prefix/bin/agent-notifier" --agent codex --event finished || return 1
  assert_log_contains 'notify-send' || return 1
  assert_log_contains 'Codex CLI finished'
}

test_install_symlink_links_executable_and_lib_dir() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Linux
  mock_uname
  mock_record notify-send
  install_prefix="$TMP_ROOT/prefix"
  installed_script="$install_prefix/bin/agent-notifier"
  installed_lib_dir="$install_prefix/lib/agent-notifier"

  PATH="$ORIGINAL_PATH" "$ROOT/install.sh" --symlink --prefix "$install_prefix" >"$TMP_ROOT/install.out" || return 1

  [ -L "$installed_script" ] || {
    printf 'installed executable is not a symlink\n' >&2
    return 1
  }
  [ "$(readlink "$installed_script")" = "$SCRIPT" ] || {
    printf 'installed executable symlink points to %s\n' "$(readlink "$installed_script")" >&2
    return 1
  }
  [ -L "$installed_lib_dir" ] || {
    printf 'installed module directory is not a symlink\n' >&2
    return 1
  }
  [ "$(readlink "$installed_lib_dir")" = "$ROOT/lib/agent-notifier" ] || {
    printf 'installed module symlink points to %s\n' "$(readlink "$installed_lib_dir")" >&2
    return 1
  }

  printf '{}' | run_agent_notifier_as "$installed_script" --agent codex --event finished || return 1
  assert_log_contains 'notify-send' || return 1
  assert_log_contains 'Codex CLI finished'
}

test_install_symlink_runs_from_symlinked_bin_dir() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Linux
  mock_uname
  mock_record notify-send
  install_prefix="$TMP_ROOT/prefix"
  actual_bin_dir="$TMP_ROOT/dotfiles/.local/bin"
  installed_script="$install_prefix/bin/agent-notifier"
  installed_lib_dir="$install_prefix/lib/agent-notifier"
  mkdir -p "$install_prefix" "$actual_bin_dir" || return 1
  ln -s "$actual_bin_dir" "$install_prefix/bin"

  PATH="$ORIGINAL_PATH" "$ROOT/install.sh" --symlink --prefix "$install_prefix" >"$TMP_ROOT/install.out" || return 1

  [ -L "$installed_script" ] || {
    printf 'installed executable is not a symlink\n' >&2
    return 1
  }
  [ -L "$installed_lib_dir" ] || {
    printf 'installed module directory is not a symlink\n' >&2
    return 1
  }

  printf '{}' | run_agent_notifier_as "$installed_script" --agent codex --event finished || return 1
  assert_log_contains 'notify-send' || return 1
  assert_log_contains 'Codex CLI finished'
}

test_install_symlink_replaces_old_module_directory() {
  new_case || return 1
  AGENT_NOTIFIER_TEST_UNAME=Linux
  mock_uname
  mock_record notify-send
  install_prefix="$TMP_ROOT/prefix"
  installed_script="$install_prefix/bin/agent-notifier"
  installed_lib_dir="$install_prefix/lib/agent-notifier"
  mkdir -p "$install_prefix/bin" "$installed_lib_dir" || return 1
  ln -s "$SCRIPT" "$installed_script"

  for module in "$ROOT/lib/agent-notifier"/*.sh; do
    ln -s "$module" "$installed_lib_dir/$(basename -- "$module")"
  done

  PATH="$ORIGINAL_PATH" "$ROOT/install.sh" --symlink --prefix "$install_prefix" >"$TMP_ROOT/install.out" || return 1

  [ -L "$installed_lib_dir" ] || {
    printf 'old module directory was not replaced with a symlink\n' >&2
    return 1
  }
  [ "$(readlink "$installed_lib_dir")" = "$ROOT/lib/agent-notifier" ] || {
    printf 'installed module symlink points to %s\n' "$(readlink "$installed_lib_dir")" >&2
    return 1
  }

  printf '{}' | run_agent_notifier_as "$installed_script" --agent codex --event finished || return 1
  assert_log_contains 'notify-send' || return 1
  assert_log_contains 'Codex CLI finished'
}

test_install_symlink_refuses_unexpected_lib_contents() {
  new_case || return 1
  install_prefix="$TMP_ROOT/prefix"
  installed_lib_dir="$install_prefix/lib/agent-notifier"
  mkdir -p "$installed_lib_dir" || return 1
  : >"$installed_lib_dir/custom.sh"

  if PATH="$ORIGINAL_PATH" "$ROOT/install.sh" --symlink --prefix "$install_prefix" >"$TMP_ROOT/install.out" 2>"$TMP_ROOT/install.err"; then
    printf 'symlink install unexpectedly replaced a non-empty custom lib directory\n' >&2
    return 1
  fi

  [ -f "$installed_lib_dir/custom.sh" ] || {
    printf 'custom lib file was removed\n' >&2
    return 1
  }
  grep -F 'contains files not installed by agent-notifier' "$TMP_ROOT/install.err" >/dev/null 2>&1 || {
    printf 'expected clear error for custom lib directory\n' >&2
    return 1
  }
}

test_uninstall_removes_installed_bootstrap_module() {
  new_case || return 1
  install_prefix="$TMP_ROOT/prefix"
  install_bin_dir="$install_prefix/bin"
  install_lib_dir="$install_prefix/lib/agent-notifier"
  mkdir -p "$install_bin_dir" "$install_lib_dir" || return 1
  : >"$install_bin_dir/agent-notifier"

  for module in bootstrap cli core notify notify_local notify_tmux notify_ntfy tmux; do
    : >"$install_lib_dir/$module.sh"
  done

  PATH="$ORIGINAL_PATH" "$ROOT/uninstall.sh" --prefix "$install_prefix" >"$TMP_ROOT/uninstall.out" || return 1
  [ ! -e "$install_lib_dir/bootstrap.sh" ] || {
    printf 'bootstrap module was not removed\n' >&2
    return 1
  }
  [ ! -d "$install_lib_dir" ] || {
    printf 'module directory was not removed\n' >&2
    return 1
  }
}

test_uninstall_removes_symlinked_lib_directory() {
  new_case || return 1
  install_prefix="$TMP_ROOT/prefix"
  install_bin_dir="$install_prefix/bin"
  install_lib_parent="$install_prefix/lib"
  install_lib_dir="$install_lib_parent/agent-notifier"
  mkdir -p "$install_bin_dir" "$install_lib_parent" || return 1
  ln -s "$SCRIPT" "$install_bin_dir/agent-notifier"
  ln -s "$ROOT/lib/agent-notifier" "$install_lib_dir"

  PATH="$ORIGINAL_PATH" "$ROOT/uninstall.sh" --prefix "$install_prefix" >"$TMP_ROOT/uninstall.out" || return 1
  [ ! -e "$install_lib_dir" ] && [ ! -L "$install_lib_dir" ] || {
    printf 'symlinked module directory was not removed\n' >&2
    return 1
  }
}

main "$@"
