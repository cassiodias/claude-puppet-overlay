# Install

You need macOS, [Homebrew](https://brew.sh) and Claude Code. Steps 1 to 4 are copy and paste into a terminal; step 5 is a few clicks only you can do.

## 1. Install Hammerspoon

```sh
brew install --cask hammerspoon
```

## 2. Get the files

```sh
git clone https://github.com/cassiodias/claude-puppet-overlay.git ~/.claude-puppet/src
mkdir -p ~/.hammerspoon/Spoons
cp -R ~/.claude-puppet/src/ClaudePuppet.spoon ~/.hammerspoon/Spoons/
cp ~/.claude-puppet/src/hook/claude-puppet-hook.sh ~/.claude-puppet/hook.sh
```

## 3. Load the puppet in Hammerspoon

```sh
cat >> ~/.hammerspoon/init.lua <<'LUA'
hs.loadSpoon("ClaudePuppet")
spoon.ClaudePuppet:start()
LUA
```

## 4. Connect Claude Code

This puts the puppet's hooks in `~/.claude/settings.json`. It saves a backup first, keeps everything else in the file, and replaces any puppet hooks already there, so it is safe to run again:

```sh
cd ~/.claude-puppet/src
[ -f ~/.claude/settings.json ] || echo '{}' > ~/.claude/settings.json
cp ~/.claude/settings.json ~/.claude/settings.json.bak
jq '.hooks |= ((. // {}) | with_entries(.value |= map(select(all(.hooks[]; .command | test("claude-puppet") | not)))) | with_entries(select(.value | length > 0)))' \
  ~/.claude/settings.json > /tmp/claude-puppet-clean.json
jq -s '.[0] as $mine | .[1].hooks as $add | $mine | .hooks = (reduce ($add | keys[]) as $e (($mine.hooks // {}); .[$e] = ((.[$e] // []) + $add[$e])))' \
  /tmp/claude-puppet-clean.json hook/hooks.json > ~/.claude/settings.json
rm /tmp/claude-puppet-clean.json
```

`jq` comes with macOS 15 and later; on older versions run `brew install jq` first.

## 5. Things only you can do

macOS asks you for these, and no script can click them for you:

1. **Open Hammerspoon:** `open -a Hammerspoon`. On the first launch it shows a setup window.
2. **Allow Accessibility:** System Settings → Privacy & Security → **Accessibility** → turn on **Hammerspoon**. Without it you cannot drag the puppet or click it to jump to your terminal.
3. **Launch at login:** click the Hammerspoon icon in the menu bar → **Preferences** → tick **Launch Hammerspoon at login**. Otherwise the puppet is gone after a restart.
4. **Reload:** click the Hammerspoon icon → **Reload Config**. A puppet appears in the bottom right corner of your main screen, with a `▟▙` icon in the menu bar to hide the puppets or move them back to the corner. More puppets line up to its left while several Claude sessions are busy.
5. **Start a new Claude Code session.** Sessions that were already open do not pick up the new hooks.

## 6. Try it

Ask Claude anything in the new session. The puppet thinks, then types; when Claude finishes, it says the first sentence of the answer. Click it to jump to that terminal.

To see ping pong, ask Claude for two subagents at once, for example: *"Use two subagents in parallel: one lists this folder, the other prints today's date."*

## Only for some commands

By default the puppet acts out every turn. To have it play only while some slash commands or skills run, list them in `~/.hammerspoon/init.lua`, before the `start()` line:

```lua
hs.loadSpoon("ClaudePuppet")
spoon.ClaudePuppet.commands = { "code-review", "my-coding-skill" }
spoon.ClaudePuppet:start()
```

Then **Reload Config**. A turn plays when you type one of them (`/my-coding-skill ...`) or when Claude calls one through its Skill tool, from that call on. Other turns leave the puppet idle. `spoon.ClaudePuppet.pixel = 5` makes it bigger (the default is 4).

## Update

```sh
git -C ~/.claude-puppet/src pull
cp -R ~/.claude-puppet/src/ClaudePuppet.spoon ~/.hammerspoon/Spoons/
cp ~/.claude-puppet/src/hook/claude-puppet-hook.sh ~/.claude-puppet/hook.sh
```

Then run step 4 again (a new version may listen to more events), **Reload Config** in Hammerspoon, and start a new Claude Code session.

## Uninstall

```sh
cp ~/.claude/settings.json ~/.claude/settings.json.bak
jq '.hooks |= ((. // {}) | with_entries(.value |= map(select(all(.hooks[]; .command | test("claude-puppet") | not)))) | with_entries(select(.value | length > 0)))' \
  ~/.claude/settings.json > /tmp/claude-puppet-clean.json && mv /tmp/claude-puppet-clean.json ~/.claude/settings.json
rm -rf ~/.hammerspoon/Spoons/ClaudePuppet.spoon ~/.claude-puppet
```

Then delete the `ClaudePuppet` lines from `~/.hammerspoon/init.lua` and **Reload Config**. Hammerspoon itself stays; `brew uninstall --cask hammerspoon` removes it too, and you can turn its Accessibility switch off in System Settings.

## If something does not work

- **The puppet does not move:** run `tail -f ~/.claude-puppet/events` while Claude works. A line per event means the hook runs and the problem is on the Hammerspoon side: open **Console** from its menu bar icon to see errors. No lines: start a new Claude Code session, and check that `/hooks` in Claude Code lists `~/.claude-puppet/hook.sh`.
- **Cannot drag or click it:** Accessibility is off for Hammerspoon (step 5.2). After turning it on, quit and reopen Hammerspoon.
- **A click does not reach the right window:** the puppet knows iTerm2, Terminal, Ghostty, WezTerm, Warp, VS Code, Hyper, Tabby and Zed. It brings the app forward and picks the window whose title has the project folder's name; in other terminals a click does nothing.
