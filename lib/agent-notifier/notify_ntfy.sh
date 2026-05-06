notify_ntfy() {
  load_ntfy_config
  ntfy_can_send || return 0

  ntfy_build_curl_args
  curl "${ntfy_curl_args[@]}" >/dev/null 2>&1 || true
}

load_ntfy_config() {
  config_file=$(ntfy_config_file)
  [ -f "$config_file" ] || return 0

  while IFS= read -r line || [ -n "$line" ]; do
    load_ntfy_config_line "$line"
  done <"$config_file"
}

ntfy_can_send() {
  [ -n "${NTFY_TOPIC:-}" ] && have curl
}

ntfy_build_curl_args() {
  server=$(ntfy_server_url)
  topic=$(ntfy_topic_path)
  priority=$(ntfy_priority)
  tags=$(ntfy_tags)

  ntfy_curl_args=(
    -fsS
    --connect-timeout 2
    --max-time 3
    -X POST
    "$server/$topic"
    -H "Title: $title"
    -H "Priority: $priority"
    -H "Tags: $tags"
  )
  ntfy_add_auth_header
  ntfy_curl_args+=(--data-binary "$body")
}

ntfy_config_file() {
  if [ -n "${AGENT_NOTIFIER_NTFY_ENV:-}" ]; then
    printf '%s' "$AGENT_NOTIFIER_NTFY_ENV"
  else
    printf '%s/.config/agent-notifier/ntfy.env' "$HOME"
  fi
}

load_ntfy_config_line() {
  case "$1" in
    ''|'#'*) return 0 ;;
  esac

  key=${1%%=*}
  value=${1#*=}
  key=$(ntfy_config_key "$key")
  value=$(strip_config_value "$value")

  apply_ntfy_config_value "$key" "$value"
}

apply_ntfy_config_value() {
  case "$1" in
    NTFY_TOPIC) [ -z "${NTFY_TOPIC:-}" ] && NTFY_TOPIC=$2 ;;
    NTFY_SERVER) [ -z "${NTFY_SERVER:-}" ] && NTFY_SERVER=$2 ;;
    NTFY_TOKEN) [ -z "${NTFY_TOKEN:-}" ] && NTFY_TOKEN=$2 ;;
  esac
}

ntfy_server_url() {
  server=${NTFY_SERVER:-https://ntfy.sh}
  printf '%s' "${server%/}"
}

ntfy_topic_path() {
  printf '%s' "${NTFY_TOPIC#/}"
}

ntfy_priority() {
  if [ "$event" = "interaction" ]; then
    printf 'high'
  else
    printf 'default'
  fi
}

ntfy_tags() {
  if [ "$event" = "interaction" ]; then
    printf 'warning'
  else
    printf 'heavy_check_mark'
  fi
}

ntfy_add_auth_header() {
  if [ -n "${NTFY_TOKEN:-}" ]; then
    ntfy_curl_args+=(-H "Authorization: Bearer $NTFY_TOKEN")
  fi
}

ntfy_config_key() {
  printf '%s' "$1" | sed 's/^[[:space:]]*export[[:space:]]*//; s/^[[:space:]]*//; s/[[:space:]]*$//'
}

strip_config_value() {
  value=$1
  value=$(printf '%s' "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  case "$value" in
    \"*\") value=${value#\"}; value=${value%\"} ;;
    \'*\') value=${value#\'}; value=${value%\'} ;;
  esac
  printf '%s' "$value"
}
