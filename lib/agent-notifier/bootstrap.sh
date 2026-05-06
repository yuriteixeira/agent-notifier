agent_notifier_source_modules() {
  for agent_notifier_module in core tmux notify_local notify_tmux notify_ntfy notify cli; do
    agent_notifier_source_module "$1" "$agent_notifier_module"
  done
}

agent_notifier_source_module() {
  agent_notifier_module_path=$1/$2.sh
  if [ ! -f "$agent_notifier_module_path" ]; then
    printf 'agent-notifier: missing module: %s\n' "$agent_notifier_module_path" >&2
    exit 70
  fi
  . "$agent_notifier_module_path"
}
