#!/bin/sh
# Runs every test: the Spoon's scenario snapshots and the harness fixtures. Needs Lua 5.4 (brew install lua@5.4).
set -e
cd "$(dirname "$0")/.."
LUA=$(command -v lua5.4 || command -v lua-5.4 || echo /opt/homebrew/opt/lua@5.4/bin/lua)
for test in tests/*_test.lua; do "$LUA" "$test"; done
[ -x tests/harnesses.sh ] && tests/harnesses.sh
exit 0
