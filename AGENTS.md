# Repository Guidelines

## Project Structure & Module Organization

This repository ships a Bash utility for agent hook notifications.

- `bin/agent-notifier` is the main executable and module loader.
- `lib/agent-notifier/*.sh` contains focused runtime modules for CLI flow, shared helpers, tmux integration, and notification backends.
- `install.sh` and `uninstall.sh` manage local installation and printed hook snippets.
- `test/run-tests.sh` is the shell test harness.
- `test/fixtures/*.json` contains sample Claude, Codex, and Gemini hook payloads.
- `README.md` is the user-facing setup and usage reference.

## Build, Test, and Development Commands

- `./test/run-tests.sh` runs the full test suite with mocked OS tools, tmux, and ntfy/curl behavior.
- `printf '{}' | ./bin/agent-notifier --agent claude --event finished` smoke-tests the CLI locally.
- `./install.sh` copies the executable and support modules under `~/.local` and prints configuration snippets.
- `./install.sh --symlink` installs a symlink for local development.
- `./uninstall.sh` removes the installed script and support modules but does not edit user hook configuration.

There is no compile step or package manager workflow.

## Coding Style & Naming Conventions

Use portable Bash and POSIX-style utilities already used by the project (`sed`, `tr`, `awk`, `head`, `cat`, `basename`, `dirname`, `readlink`). Keep functions small and named in lowercase with underscores, for example `notify_ntfy` or `json_string_value`. Prefer explicit `case` statements for CLI parsing and supported values. Use two-space indentation inside functions and control blocks, matching the current scripts. Preserve best-effort notification behavior: backend failures should not block hooks, but invalid CLI usage should fail non-zero.

## Quality Criteria

Apply SOLID principles pragmatically for a small Bash utility: keep functions focused on one responsibility, separate CLI parsing, payload normalization, message formatting, configuration loading, and notification backends, and depend on narrow helper functions instead of duplicating shell logic. Follow Clean Code guidelines: use intention-revealing names, keep control flow simple, remove duplication, make error handling explicit, and add comments only when they clarify non-obvious behavior. Refactors should improve readability and testability without introducing unnecessary files, abstractions, or runtime dependencies.

## Testing Guidelines

Add or update tests in `test/run-tests.sh` for every behavior change. Use focused `test_*` functions, call `new_case`, mock external commands with `mock_record` or `mock_cmd`, and register each case with `run_test`. Add JSON payload examples to `test/fixtures/` when they represent a real agent hook shape. Run `./test/run-tests.sh` before submitting changes.

## Commit & Pull Request Guidelines

The history currently uses short lowercase summaries, such as `initial commit`. Keep commit messages concise and imperative when possible, for example `add ntfy token handling`. Pull requests should describe user-visible behavior, list test results, and note any changes to hook snippets, installation paths, or notification backend behavior.

## Security & Configuration Tips

Do not commit real ntfy topics, tokens, or personal hook configuration. Document examples with placeholders only. Treat `~/.config/agent-notifier/ntfy.env` as local user state, not repository data.
