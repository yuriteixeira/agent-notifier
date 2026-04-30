# agent-notify

One small local notifier for Claude Code, Codex CLI, and Gemini CLI hooks.

`agent-notify` sends best-effort notifications when an agent finishes a turn or
needs user interaction. It uses local OS notifications, tmux messages when
running inside tmux, and optional remote ntfy publishing.

## Features

- Single Bash script: `bin/agent-notify`
- macOS local notifications through `osascript`
- Linux local notifications through `notify-send`
- tmux `display-message` plus terminal bell when running inside tmux
- Optional ntfy publish via `curl`
- Reads hook JSON from stdin
- Accepts Codex legacy JSON as the first positional argument
- Exits `0` when notification backends fail so hooks do not block the agent

Invalid CLI flags or invalid `--agent` / `--event` values exit non-zero.

## Install

Clone the repo, then run:

```sh
./install.sh
```

By default this copies `bin/agent-notify` to:

```text
~/.local/bin/agent-notify
```

To install as a symlink instead:

```sh
./install.sh --symlink
```

To install somewhere else:

```sh
./install.sh --prefix /opt/agent-notify
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
printf '{}' | agent-notify --agent claude --event finished
printf '{"message":"Permission required"}' | agent-notify --agent codex --event interaction
printf '{"last_assistant_message":"Done"}' | agent-notify --agent gemini --event finished
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
`agent-notify` treats it as a Codex payload and derives the event from common
fields such as `notification_type`, `hook_event_name`, `event`, and `type`.

```sh
agent-notify '{"notification_type":"agent-turn-complete","message":"Done"}'
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
            "command": "\"/Users/you/.local/bin/agent-notify\" --agent claude --event finished",
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
            "command": "\"/Users/you/.local/bin/agent-notify\" --agent claude --event interaction",
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
            "command": "\"/Users/you/.local/bin/agent-notify\" --agent claude --event interaction",
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
            "command": "\"/Users/you/.local/bin/agent-notify\" --agent claude --event interaction",
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
            "command": "\"/Users/you/.local/bin/agent-notify\" --agent claude --event interaction",
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
command = '"/Users/you/.local/bin/agent-notify" --agent codex --event finished'
timeout = 5
statusMessage = "Sending notification"

[[hooks.PermissionRequest]]
matcher = "*"
[[hooks.PermissionRequest.hooks]]
type = "command"
command = '"/Users/you/.local/bin/agent-notify" --agent codex --event interaction'
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
            "name": "agent-notify-finished",
            "type": "command",
            "command": "\"/Users/you/.local/bin/agent-notify\" --agent gemini --event finished"
          }
        ]
      }
    ]
  }
}
```

`general.enableNotifications` covers Gemini terminal notifications for
action-required prompts and session completion. The hook above adds the shared
`agent-notify` completion path.

Gemini settings docs:
<https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/settings.md>

Gemini hook docs:
<https://github.com/google-gemini/gemini-cli/blob/main/docs/hooks/writing-hooks.md>

## ntfy

ntfy is opt-in. If no topic is configured, `agent-notify` skips ntfy silently.

Configuration is read from environment variables first:

```sh
export NTFY_TOPIC=replace-with-a-long-random-private-topic
export NTFY_SERVER=https://ntfy.sh
export NTFY_TOKEN=optional-access-token
```

If `NTFY_TOPIC` is not set, `agent-notify` falls back to:

```text
~/.config/agent-notify/ntfy.env
```

Example:

```sh
mkdir -p ~/.config/agent-notify
cat > ~/.config/agent-notify/ntfy.env <<'EOF'
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
printf '{}' | ~/.local/bin/agent-notify --agent claude --event finished
printf '{"cwd":"'"$PWD"'","message":"Permission required"}' | NTFY_TOPIC=replace-with-a-long-random-private-topic ~/.local/bin/agent-notify --agent codex --event interaction
```

Run those inside and outside tmux. Backend failures should not make the command
fail.

## Troubleshooting

- No macOS notification: confirm `osascript` is available and notifications are
  allowed for your terminal app.
- No Linux notification: install a desktop notification implementation that
  provides `notify-send`, such as `libnotify`.
- No tmux message: tmux notifications only run when `$TMUX` is set and the
  `tmux` command is available.
- No ntfy message: confirm `curl` exists and `NTFY_TOPIC` is set in the hook
  environment or in `~/.config/agent-notify/ntfy.env`.
- Hook config does not load: validate each tool separately. Claude users can
  inspect `/hooks`; Codex users should confirm hooks load on startup; Gemini
  users should confirm `settings.json` parses.
