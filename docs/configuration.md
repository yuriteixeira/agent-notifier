# Configuration

Run `./install.sh` first. The installer prints snippets with the command path
for your install location. If you copy examples from this file instead, adjust
`$HOME/.local/bin/agent-notifier` when needed.

## Contents

- [Claude Code](#claude-code)
- [Codex CLI](#codex-cli)
- [Gemini CLI](#gemini-cli)
- [ntfy](#ntfy)
- [Manual Usage](#manual-usage)

## Claude Code

Add this shape to `~/.claude/settings.json`:

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

Add this shape to `~/.codex/config.toml`:

```toml
[features]
codex_hooks = true

[tui]
notifications = true
notification_condition = "always"
notification_method = "auto"

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

If you already have a `[tui]` table, merge the three notification keys into it
instead of adding a second `[tui]` header.

Codex hook docs: <https://developers.openai.com/codex/hooks>

## Gemini CLI

Add this shape to `~/.gemini/settings.json`:

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

Gemini settings docs:
<https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/settings.md>

Gemini hook docs:
<https://github.com/google-gemini/gemini-cli/blob/main/docs/hooks/writing-hooks.md>

## ntfy

ntfy is optional. If no topic is configured, `agent-notifier` skips ntfy.

⚠️ **Do not use public ntfy.sh topics for sensitive, confidential, or corporate
projects unless you have confirmed it is allowed.** Anyone who knows a public
topic can subscribe unless the ntfy server enforces authentication.

For corporate projects, ⚠️ **contact your security department before enabling
ntfy publishing.** Local desktop and tmux notifications do not require ntfy.

Environment variables:

```sh
export NTFY_TOPIC=replace-with-a-long-random-private-topic
export NTFY_SERVER=https://ntfy.sh
export NTFY_TOKEN=optional-access-token
```

Config file fallback:

```sh
mkdir -p ~/.config/agent-notifier
cat > ~/.config/agent-notifier/ntfy.env <<'EOF'
NTFY_TOPIC=replace-with-a-long-random-private-topic
NTFY_SERVER=https://ntfy.sh
# NTFY_TOKEN=optional-access-token
EOF
```

Use a long unpredictable topic. Anyone who knows a public ntfy.sh topic can
subscribe unless your server enforces authentication.

Interaction events publish with high priority. Finished events publish with
default priority.

ntfy publish docs: <https://docs.ntfy.sh/publish/>

## Manual Usage

```sh
printf '{}' | agent-notifier --agent claude --event finished
printf '{"message":"Permission required"}' | agent-notifier --agent codex --event interaction
printf '{"last_assistant_message":"Done"}' | agent-notifier --agent gemini --event finished
```

Supported agents: `claude`, `codex`, `gemini`.

Supported events: `finished`, `interaction`.

Codex legacy notification payloads can also be passed as the first positional
argument:

```sh
agent-notifier '{"notification_type":"agent-turn-complete","message":"Done"}'
```
