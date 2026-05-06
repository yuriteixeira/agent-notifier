strip_config_value() {
  value=$1
  value=$(printf '%s' "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  case "$value" in
    \"*\") value=${value#\"}; value=${value%\"} ;;
    \'*\') value=${value#\'}; value=${value%\'} ;;
  esac
  printf '%s' "$value"
}

load_ntfy_dotfile() {
  default_config_file=$HOME/.config/agent-notifier/ntfy.env

  if [ -n "${AGENT_NOTIFIER_NTFY_ENV:-}" ]; then
    config_file=$AGENT_NOTIFIER_NTFY_ENV
  else
    config_file=$default_config_file
  fi

  [ -f "$config_file" ] || return 0

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|'#'*) continue ;;
    esac

    key=${line%%=*}
    value=${line#*=}
    key=$(printf '%s' "$key" | sed 's/^[[:space:]]*export[[:space:]]*//; s/^[[:space:]]*//; s/[[:space:]]*$//')
    value=$(strip_config_value "$value")

    case "$key" in
      NTFY_TOPIC) [ -z "${NTFY_TOPIC:-}" ] && NTFY_TOPIC=$value ;;
      NTFY_SERVER) [ -z "${NTFY_SERVER:-}" ] && NTFY_SERVER=$value ;;
      NTFY_TOKEN) [ -z "${NTFY_TOKEN:-}" ] && NTFY_TOKEN=$value ;;
    esac
  done <"$config_file"
}

notify_ntfy() {
  load_ntfy_dotfile
  [ -n "${NTFY_TOPIC:-}" ] || return 0
  have curl || return 0

  server=${NTFY_SERVER:-https://ntfy.sh}
  server=${server%/}
  topic=${NTFY_TOPIC#/}
  priority=default
  tags=heavy_check_mark
  if [ "$event" = "interaction" ]; then
    priority=high
    tags=warning
  fi

  curl_args=(
    -fsS
    --connect-timeout 2
    --max-time 3
    -X POST
    "$server/$topic"
    -H "Title: $title"
    -H "Priority: $priority"
    -H "Tags: $tags"
  )
  if [ -n "${NTFY_TOKEN:-}" ]; then
    curl_args+=(-H "Authorization: Bearer $NTFY_TOKEN")
  fi
  curl_args+=(--data-binary "$body")

  curl "${curl_args[@]}" >/dev/null 2>&1 || true
}
