# Repository Guidelines

## Project Structure & Module Organization

This repository ships a single Bash utility for agent hook notifications.

- `bin/agent-notify` is the main executable. Keep core behavior here unless a new file is clearly justified.
- `install.sh` and `uninstall.sh` manage local installation and printed hook snippets.
- `test/run-tests.sh` is the shell test harness.
- `test/fixtures/*.json` contains sample Claude, Codex, and Gemini hook payloads.
- `README.md` is the user-facing setup and usage reference.

## Build, Test, and Development Commands

- `./test/run-tests.sh` runs the full test suite with mocked OS tools, tmux, and ntfy/curl behavior.
- `printf '{}' | ./bin/agent-notify --agent claude --event finished` smoke-tests the CLI locally.
- `./install.sh` copies the executable to `~/.local/bin/agent-notify` and prints configuration snippets.
- `./install.sh --symlink` installs a symlink for local development.
- `./uninstall.sh` removes the installed script but does not edit user hook configuration.

There is no compile step or package manager workflow.

## Coding Style & Naming Conventions

Use portable Bash and POSIX-style utilities already used by the project (`sed`, `tr`, `awk`, `head`, `cat`, `basename`). Keep functions small and named in lowercase with underscores, for example `notify_ntfy` or `json_string_value`. Prefer explicit `case` statements for CLI parsing and supported values. Use two-space indentation inside functions and control blocks, matching the current scripts. Preserve best-effort notification behavior: backend failures should not block hooks, but invalid CLI usage should fail non-zero.

## Testing Guidelines

Add or update tests in `test/run-tests.sh` for every behavior change. Use focused `test_*` functions, call `new_case`, mock external commands with `mock_record` or `mock_cmd`, and register each case with `run_test`. Add JSON payload examples to `test/fixtures/` when they represent a real agent hook shape. Run `./test/run-tests.sh` before submitting changes.

## Commit & Pull Request Guidelines

The history currently uses short lowercase summaries, such as `initial commit`. Keep commit messages concise and imperative when possible, for example `add ntfy token handling`. Pull requests should describe user-visible behavior, list test results, and note any changes to hook snippets, installation paths, or notification backend behavior.

## Security & Configuration Tips

Do not commit real ntfy topics, tokens, or personal hook configuration. Document examples with placeholders only. Treat `~/.config/agent-notify/ntfy.env` as local user state, not repository data.
