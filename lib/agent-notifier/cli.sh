main() {
  parse_args "$@"
  read_payload
  resolve_agent
  resolve_event
  load_tmux_context
  build_notification
  notify_all
}

parse_args() {
  agent=
  event=
  payload_arg=

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --agent)
        [ "$#" -ge 2 ] || fail_usage '--agent requires a value'
        agent=$2
        shift 2
        ;;
      --agent=*)
        agent=${1#--agent=}
        shift
        ;;
      --event)
        [ "$#" -ge 2 ] || fail_usage '--event requires a value'
        event=$2
        shift 2
        ;;
      --event=*)
        event=${1#--event=}
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        fail_usage "unknown flag: $1"
        ;;
      *)
        if [ -z "$payload_arg" ]; then
          payload_arg=$1
        else
          fail_usage "unexpected positional argument: $1"
        fi
        shift
        ;;
    esac
  done

  if [ "$#" -gt 0 ]; then
    if [ -z "$payload_arg" ] && [ "$#" -eq 1 ]; then
      payload_arg=$1
    else
      fail_usage 'unexpected positional arguments'
    fi
  fi
}

read_payload() {
  if [ -n "$payload_arg" ]; then
    payload=$payload_arg
  elif [ ! -t 0 ]; then
    payload=$(cat)
  else
    payload=
  fi
}

resolve_agent() {
  if [ -n "$agent" ]; then
    agent=$(normalize_agent "$agent") || fail_usage 'invalid --agent; expected claude, codex, or gemini'
    return 0
  fi

  payload_agent=$(first_json_value agent cli source)
  agent=$(normalize_agent "$payload_agent" 2>/dev/null || true)
  if [ -z "$agent" ] && [ -n "$payload" ]; then
    agent=codex
  fi
  [ -n "$agent" ] || fail_usage '--agent is required when no payload can identify the agent'
}

resolve_event() {
  if [ -n "$event" ]; then
    event=$(lower "$event")
  else
    event=$(event_from_payload)
  fi

  case "$event" in
    finished|interaction) ;;
    *) fail_usage 'invalid --event; expected finished or interaction' ;;
  esac
}

build_notification() {
  title=$(title_for)
  body=$(body_for)
}
