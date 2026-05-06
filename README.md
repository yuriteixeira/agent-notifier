# agent-notifier

One small local notifier for Claude Code, Codex CLI, and Gemini CLI hooks.

`agent-notifier` sends best-effort notifications when an agent finishes a turn or
needs user interaction. It uses local OS notifications, tmux messages when
running inside tmux, and optional remote ntfy publishing.

## Features

- Small Bash CLI: `bin/agent-notifier` with support modules in `lib/agent-notifier/`
- macOS local notifications through `osascript`
- Linux local notifications through `notify-send`
- tmux session names in notification text when running inside tmux
- Centered tmux menu notifications that can switch back to the agent pane
- Optional ntfy publish via `curl`
- Reads hook JSON from stdin
- Accepts Codex legacy JSON as the first positional argument
- Converts common Markdown formatting in agent text to plain notifications
- Exits `0` when notification backends fail so hooks do not block the agent

Invalid CLI flags or invalid `--agent` / `--event` values exit non-zero.

## Install

Clone the repo, then run:

```sh
./install.sh
```

By default this copies `bin/agent-notifier` and its support modules to:

```text
~/.local/bin/agent-notifier
~/.local/lib/agent-notifier/
```

When `--bin-dir` is used, support modules are installed in a sibling
`lib/agent-notifier/` directory next to the chosen bin directory.

To install as a symlink instead:

```sh
./install.sh --symlink
```

This links both `~/.local/bin/agent-notifier` and the sibling
`~/.local/lib/agent-notifier/` support module directory back to the clone.

To install somewhere else:

```sh
./install.sh --prefix /opt/agent-notifier
./install.sh --bin-dir "$HOME/bin"
```

The installer prints ready-to-paste config snippets. It does not edit
`~/.claude/settings.json`, `~/.codex/config.toml`, or
`~/.gemini/settings.json`.

## Uninstall

```sh
./uninstall.sh
```

Then remove any pasted hook snippets manually from Claude, Codex, Gemini, and
ntfy config files.

## Usage

```sh
printf '{}' | agent-notifier --agent claude --event finished
printf '{"message":"Permission required"}' | agent-notifier --agent codex --event interaction
printf '{"last_assistant_message":"Done"}' | agent-notifier --agent gemini --event finished
```

Supported agents:

- `claude`
- `codex`
- `gemini`

Supported events:

- `finished`
- `interaction`

For Codex legacy notification commands, JSON can be passed as the first
positional argument. If no agent is specified and a JSON payload is present,
`agent-notifier` treats it as a Codex payload and derives the event from common
fields such as `notification_type`, `hook_event_name`, `event`, and `type`.

```sh
agent-notifier '{"notification_type":"agent-turn-complete","message":"Done"}'
```

## Claude Code

Add this shape to `~/.claude/settings.json`, adjusting the command path if you
installed somewhere other than `~/.local/bin`.

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$HOME/.local/bin/agent-notifier\" --agent claude --event finished",
            "async": true
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "\"$HOME/.local/bin/agent-notifier\" --agent claude --event interaction",
            "async": true
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$HOME/.local/bin/agent-notifier\" --agent claude --event interaction",
            "async": true
          }
        ]
      }
    ],
    "Elicitation": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$HOME/.local/bin/agent-notifier\" --agent claude --event interaction",
            "async": true
          }
        ]
      }
    ],
    "TeammateIdle": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$HOME/.local/bin/agent-notifier\" --agent claude --event interaction",
            "async": true
          }
        ]
      }
    ]
  }
}
```

Claude hook docs: <https://code.claude.com/docs/en/hooks>

## Codex CLI

Add this shape to `~/.codex/config.toml`, adjusting the command path if needed.

```toml
[features]
codex_hooks = true

[[hooks.Stop]]
[[hooks.Stop.hooks]]
type = "command"
command = '"$HOME/.local/bin/agent-notifier" --agent codex --event finished'
timeout = 5
statusMessage = "Sending notification"

[[hooks.PermissionRequest]]
matcher = "*"
[[hooks.PermissionRequest.hooks]]
type = "command"
command = '"$HOME/.local/bin/agent-notifier" --agent codex --event interaction'
timeout = 5
statusMessage = "Sending notification"
```

Codex hooks are behind the `codex_hooks` feature flag. Codex also has terminal
notification settings for supported completion and action-required surfaces;
use those in addition to hooks if you want built-in TUI notifications.

Codex hook docs: <https://developers.openai.com/codex/hooks>

## Gemini CLI

Add this shape to `~/.gemini/settings.json`, adjusting the command path if
needed.

```json
{
  "general": {
    "enableNotifications": true,
    "notificationMethod": "auto"
  },
  "hooks": {
    "AfterAgent": [
      {
        "matcher": "*",
        "hooks": [
          {
            "name": "agent-notifier-finished",
            "type": "command",
            "command": "\"$HOME/.local/bin/agent-notifier\" --agent gemini --event finished"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "*",
        "hooks": [
          {
            "name": "agent-notifier-interaction",
            "type": "command",
            "command": "\"$HOME/.local/bin/agent-notifier\" --agent gemini --event interaction"
          }
        ]
      }
    ]
  }
}
```

`AfterAgent` covers completed turns. `Notification` covers Gemini system alerts
such as tool permission prompts, and forwards them through the shared
`agent-notifier` interaction path.

Gemini settings docs:
<https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/settings.md>

Gemini hook docs:
<https://github.com/google-gemini/gemini-cli/blob/main/docs/hooks/writing-hooks.md>

## ntfy

ntfy is opt-in. If no topic is configured, `agent-notifier` skips ntfy silently.

Configuration is read from environment variables first:

```sh
export NTFY_TOPIC=replace-with-a-long-random-private-topic
export NTFY_SERVER=https://ntfy.sh
export NTFY_TOKEN=optional-access-token
```

If `NTFY_TOPIC` is not set, `agent-notifier` falls back to:

```text
~/.config/agent-notifier/ntfy.env
```

Example:

```sh
mkdir -p ~/.config/agent-notifier
cat > ~/.config/agent-notifier/ntfy.env <<'EOF'
NTFY_TOPIC=replace-with-a-long-random-private-topic
NTFY_SERVER=https://ntfy.sh
# NTFY_TOKEN=optional-access-token
EOF
```

Use a long unpredictable topic. Treat it like a secret: anyone who knows a
public ntfy.sh topic can subscribe unless your server enforces authentication.

Interaction events publish with `Priority: high`; finished events publish with
`Priority: default`.

ntfy publish docs: <https://docs.ntfy.sh/publish/>

## Testing

Run the shell tests:

```sh
bash test/run-tests.sh
```

Manual smoke tests:

```sh
printf '{}' | ~/.local/bin/agent-notifier --agent claude --event finished
printf '{"cwd":"'"$PWD"'","message":"Permission required"}' | NTFY_TOPIC=replace-with-a-long-random-private-topic ~/.local/bin/agent-notifier --agent codex --event interaction
```

Run those inside and outside tmux. Backend failures should not make the command
fail.

## Troubleshooting

- No macOS notification: confirm `osascript` is available and notifications are
  allowed for your terminal app.
- No Linux notification: install a desktop notification implementation that
  provides `notify-send`, such as `libnotify`.
- No tmux message: tmux notifications only run when `$TMUX` is set and the
  `tmux` command is available. Centered selectable notifications use
  `display-menu` to focus the originating session, window, and pane; older tmux
  versions fall back to a styled `display-message`.
- No ntfy message: confirm `curl` exists and `NTFY_TOPIC` is set in the hook
  environment or in `~/.config/agent-notifier/ntfy.env`.
- Hook exits with code `127`: run `./install.sh` and make sure the hook
  command points to `$HOME/.local/bin/agent-notifier` or your custom install
  path.
- Hook config does not load: validate each tool separately. Claude users can
  inspect `/hooks`; Codex users should confirm hooks load on startup; Gemini
  users should confirm `settings.json` parses.
