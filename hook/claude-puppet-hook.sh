#!/bin/sh
# Claude Code runs this on each hook event: it appends one short line for the floating puppet to read.
# Line: time|event|session|agent|tool|agent type|text. Only a leading /command of a prompt is kept.

dir="$HOME/.claude-puppet"
file="$dir/events"
mkdir -p "$dir"
json=$(cat)

field() {
  value=$(printf '%s' "$json" | plutil -extract "$1" raw -o - - 2>/dev/null) || return 0
  printf '%s' "$value" | tr '\n|' '  ' | cut -c1-120
}

event=$(field hook_event_name)
text=""
case "$event" in
  UserPromptSubmit)
    prompt=$(field prompt)
    case "$prompt" in /*) text=${prompt%% *} ;; esac
    ;;
  Notification) text=$(field message) ;;
esac

printf '%s|%s|%s|%s|%s|%s|%s\n' "$(date +%s)" "$event" "$(field session_id)" "$(field agent_id)" \
  "$(field tool_name)" "$(field agent_type)" "$text" >> "$file"

# Keep the file small; the puppet starts reading again from the top.
[ "$(wc -c < "$file")" -gt 1000000 ] && : > "$file"
exit 0
