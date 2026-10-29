# Shared by every harness translator (harnesses/<id>/translate.sh sources it). It reads the agent's JSON
# payload and writes the one line per event the puppets read. The line format lives here and in
# ClaudePuppet.spoon/lib/puppet/events/parse.lua only:
#   time|event|session|agent id|tool|agent type|text|folder|terminal app|flag|tty|harness
# Kept from an agent: a prompt's leading /command, a skill's name, a notification, the first sentence of the
# agent's reply; never commands or code. Tests set PUPPET_NOW and PUPPET_TTY to make lines repeatable.

PUPPET_DIR="$HOME/.claude-puppet"
PUPPET_EVENTS="$PUPPET_DIR/events"

# Reads the payload from stdin once; field and first_sentence read from it.
puppet_read_payload() {
  PUPPET_PAYLOAD=$(cat)
}

# One value from the payload by key path (like tool_input.command), on one line, without "|".
field() {
  value=$(printf '%s' "$PUPPET_PAYLOAD" | plutil -extract "$1" raw -o - - 2>/dev/null) || return 0
  printf '%s' "$value" | tr '\n|' '  ' | cut -c1-120
}

# The first sentence of a text field, past any heading, without markdown marks.
first_sentence() {
  value=$(printf '%s' "$PUPPET_PAYLOAD" | plutil -extract "$1" raw -o - - 2>/dev/null) || return 0
  printf '%s\n' "$value" | grep -v -e '^[[:space:]]*$' -e '^[[:space:]]*#' | head -n 1 | tr -d '#*`|' |
    sed 's/^[[:space:]>-]*//' | sed 's/\([.!?]\)[[:space:]].*/\1/' | cut -c1-90
}

# A prompt's leading /command, or nothing.
leading_command() {
  case "$1" in /*) printf '%s' "${1%% *}" ;; esac
}

# True when a shell command runs tests, so the puppet shows a progress bar and the result.
is_test_command() {
  case " $1 " in
    *pytest*|*"npm test"*|*"npm run test"*|*"yarn test"*|*"pnpm test"*|*"go test"*|*"cargo test"*|*jest*|*vitest*|\
    *rspec*|*"mvn test"*|*"gradle test"*|*"make test"*|*" tox "*|*unittest*) return 0 ;;
  esac
  return 1
}

# The terminal the session runs in: the first ancestor process that has one, remembered per session.
puppet_tty() {
  if [ -n "${PUPPET_TTY+set}" ]; then printf '%s' "$PUPPET_TTY"; return; fi
  cache="$PUPPET_DIR/tty-$1"
  if [ -n "$1" ] && [ -f "$cache" ]; then cat "$cache"; return; fi
  tty=""
  pid=$$
  while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
    name=$(ps -o tty= -p "$pid" | tr -d ' ')
    case "$name" in
      ""|"??") pid=$(ps -o ppid= -p "$pid" | tr -d ' ') ;;
      *) tty="/dev/$name"; break ;;
    esac
  done
  [ -n "$1" ] && printf '%s' "$tty" > "$cache"
  printf '%s' "$tty"
}

# write_event harness event session agent_id tool agent_type text cwd flag
# Appends the line; the only place that writes the events file.
write_event() {
  mkdir -p "$PUPPET_DIR"
  tty=$(puppet_tty "$3")
  [ "$2" = "SessionEnd" ] && rm -f "$PUPPET_DIR/tty-$3"
  printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' "${PUPPET_NOW:-$(date +%s)}" "$2" "$3" "$4" "$5" "$6" "$7" \
    "${8##*/}" "${TERM_PROGRAM:-}" "$9" "$tty" "$1" >> "$PUPPET_EVENTS"
  # Keeps the file small; the puppets start reading again from the top.
  [ "$(wc -c < "$PUPPET_EVENTS")" -gt 1000000 ] && : > "$PUPPET_EVENTS"
  return 0
}
