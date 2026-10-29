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
3. **Allow iTerm2 control** (iTerm2 users): the first time Hammerspoon looks up your tabs, macOS asks *"Hammerspoon wants to control iTerm2"*. Click **OK**. It is how the puppets know each session's tab number and select that tab on a click. If you clicked Don't Allow, turn it on in System Settings → Privacy & Security → **Automation** → Hammerspoon → iTerm2.
4. **Launch at login:** click the Hammerspoon icon in the menu bar → **Preferences** → tick **Launch Hammerspoon at login**. Otherwise the puppet is gone after a restart.
5. **Reload:** click the Hammerspoon icon → **Reload Config**. A puppet appears in the bottom right corner of your main screen, with a `▟▙` icon in the menu bar to hide the puppets or send them to the corner of any of your screens. More puppets line up to its left while several Claude sessions are busy.
6. **Start a new Claude Code session.** Sessions that were already open do not pick up the new hooks.

## 6. Try it

Ask Claude anything in the new session. The puppet thinks, then types; when Claude finishes, it says the first sentence of the answer. Click it to jump to that terminal.

To see ping pong, ask Claude for two subagents at once, for example: *"Use two subagents in parallel: one lists this folder, the other prints today's date."*

## Only for some commands

By default the puppets act out every turn. To have them play only while some slash commands or skills run, click the `▟▙` icon in the menu bar:

- Under **Play only for**, each command you typed lately (and each skill Claude called) has a submenu: tick **Play for it**, and pick its scene: **Coder**, **Ping pong**, or **Auto** (ping pong while two subagents run, coder otherwise). **Add command…** adds one it has not seen yet, without the slash.
- **Play for every turn** goes back to playing for everything.

The choice takes effect at once, per session: with `principal-developer` set to Coder and `principal-qa-reviewer` set to Ping pong, the tab running the developer skill gets a puppet that codes, the tab running the reviewer gets one that plays ping pong, and a tab where you just chat gets no puppet. A turn plays when you type a ticked command, or from the moment Claude calls a ticked skill. Hammerspoon remembers the choice across restarts.

Menu bar icon hidden behind the notch? **Option-click any puppet** to open the same menu.

If you prefer a file, set the starting choice in `~/.hammerspoon/init.lua`, before the `start()` line (the menu's choice wins once you have used it):

```lua
spoon.ClaudePuppet.commands = { "code-review", "my-coding-skill" }
```

`spoon.ClaudePuppet.pixel = 5` makes the puppets bigger (the default is 4).

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
- **No tab number, or a click does not reach the right tab:** in iTerm2, check the Automation switch (step 5.3). Inside tmux or Zellij the puppet cannot see iTerm's tab, so it falls back to the next rule.
- **A click does not reach the right window:** outside iTerm2 the puppet knows Terminal, Ghostty, WezTerm, Warp, VS Code, Hyper, Tabby and Zed. It brings the app forward and picks the window whose title has the project folder's name; in other terminals a click does nothing.
