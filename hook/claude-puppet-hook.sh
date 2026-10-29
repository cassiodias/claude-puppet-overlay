#!/bin/sh
# Claude Code runs this on each hook event: it appends one short line for the floating puppet to read.
# Line: time|event|session|agent|tool|agent type|text|folder|terminal app|flag
# Kept: a prompt's leading /command, a notification, the first sentence of Claude's reply; never commands or code.

dir="$HOME/.claude-puppet"
file="$dir/events"
mkdir -p "$dir"
json=$(cat)

field() {
  value=$(printf '%s' "$json" | plutil -extract "$1" raw -o - - 2>/dev/null) || return 0
  printf '%s' "$value" | tr '\n|' '  ' | cut -c1-120
}

# The first sentence of Claude's last message, past any heading, without markdown marks.
first_sentence() {
  value=$(printf '%s' "$json" | plutil -extract last_assistant_message raw -o - - 2>/dev/null) || return 0
  printf '%s\n' "$value" | grep -v -e '^[[:space:]]*$' -e '^[[:space:]]*#' | head -n 1 | tr -d '#*`|' | sed 's/^[[:space:]>-]*//' |
    sed 's/\([.!?]\)[[:space:]].*/\1/' | cut -c1-90
}

event=$(field hook_event_name)
tool=$(field tool_name)
text=""
flag=""
case "$event" in
  UserPromptSubmit)
    prompt=$(field prompt)
    case "$prompt" in /*) text=${prompt%% *} ;; esac
    ;;
  Notification) text=$(field message) ;;
  Stop) text=$(first_sentence) ;;
esac
if [ "$tool" = "Bash" ]; then
  case " $(field tool_input.command) " in
    *pytest*|*"npm test"*|*"npm run test"*|*"yarn test"*|*"pnpm test"*|*"go test"*|*"cargo test"*|*jest*|*vitest*|*rspec*|*"mvn test"*|*"gradle test"*|*"make test"*|*" tox "*|*unittest*)
      flag="test" ;;
  esac
fi
cwd=$(field cwd)

printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' "$(date +%s)" "$event" "$(field session_id)" "$(field agent_id)" \
  "$tool" "$(field agent_type)" "$text" "${cwd##*/}" "${TERM_PROGRAM:-}" "$flag" >> "$file"

# Keep the file small; the puppet starts reading again from the top.
[ "$(wc -c < "$file")" -gt 1000000 ] && : > "$file"
exit 0
