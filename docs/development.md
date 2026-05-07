# Development and Troubleshooting

There is no compile step or package manager workflow.

## Local Development

```sh
./install.sh --symlink
```

This links both the executable and support module directory back to the clone.

## Tests

```sh
./test/run-tests.sh
```

Manual smoke tests:

```sh
printf '{}' | ~/.local/bin/agent-notifier --agent claude --event finished
printf '{"cwd":"'"$PWD"'","message":"Permission required"}' | NTFY_TOPIC=replace-with-a-long-random-private-topic ~/.local/bin/agent-notifier --agent codex --event interaction
```

Run smoke tests inside and outside tmux. Backend failures should not make the
command fail.

## Troubleshooting

- No macOS notification: allow notifications for your terminal app and confirm
  `osascript` is available.
- No Linux notification: install a desktop notification tool that provides
  `notify-send`, such as `libnotify`.
- No tmux message: tmux notifications only run when `$TMUX` is set and `tmux`
  is available.
- No ntfy message: confirm `curl` exists and `NTFY_TOPIC` is set in the hook
  environment or `~/.config/agent-notifier/ntfy.env`.
- Hook exits with code `127`: run `./install.sh` and make sure the hook command
  points to the installed `agent-notifier` path.
- Hook config does not load: validate each tool config separately. Claude users
  can inspect `/hooks`; Codex and Gemini users should confirm their config files
  parse on startup.
