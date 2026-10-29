#!/bin/sh
# Claude Code's hook payload into the puppet's event line. Claude Code's event names are the common
# vocabulary, so they pass through as they are.

. "$(dirname "$0")/../../hook/puppet-lib.sh"
puppet_read_payload

event=$(field hook_event_name)
tool=$(field tool_name)
text=""
case "$event" in
  UserPromptSubmit) text=$(leading_command "$(field prompt)") ;;
  Notification) text=$(field message) ;;
  Stop) text=$(first_sentence last_assistant_message) ;;
esac
[ "$tool" = "Skill" ] && text=$(field tool_input.skill)
flag=""
[ "$tool" = "Bash" ] && is_test_command "$(field tool_input.command)" && flag="test"

write_event claude "$event" "$(field session_id)" "$(field agent_id)" "$tool" "$(field agent_type)" "$text" \
  "$(field cwd)" "$flag"
exit 0
