# Install

You need macOS, [Homebrew](https://brew.sh) and Claude Code. Each step is one copy and paste into a terminal.

## 1. Install Hammerspoon

```sh
brew install --cask hammerspoon
open -a Hammerspoon
```

When Hammerspoon opens:

- Allow it in **System Settings → Privacy & Security → Accessibility** (it needs this to let you drag the puppet).
- In its Preferences, tick **Launch Hammerspoon at login** so the puppet comes back after a restart.

## 2. Get the files

```sh
git clone https://github.com/cassiodias/claude-puppet-overlay.git ~/.claude-puppet/src
mkdir -p ~/.hammerspoon/Spoons
cp -R ~/.claude-puppet/src/ClaudePuppet.spoon ~/.hammerspoon/Spoons/
cp ~/.claude-puppet/src/hook/claude-puppet-hook.sh ~/.claude-puppet/hook.sh
```

## 3. Start the puppet

```sh
cat >> ~/.hammerspoon/init.lua <<'LUA'
hs.loadSpoon("ClaudePuppet")
spoon.ClaudePuppet:start()
LUA
```

Then click the Hammerspoon icon in the menu bar → **Reload Config**. The puppet appears in the bottom right corner of your screen, with a `▟▙` icon in the menu bar to hide it or move it back to the corner.

## 4. Connect Claude Code

This adds the puppet's hook to `~/.claude/settings.json`, keeping everything already there, and saves a backup first:

```sh
cd ~/.claude-puppet/src
[ -f ~/.claude/settings.json ] || echo '{}' > ~/.claude/settings.json
cp ~/.claude/settings.json ~/.claude/settings.json.bak
jq -s '.[0] as $mine | .[1].hooks as $add | $mine | .hooks = (reduce ($add | keys[]) as $e (($mine.hooks // {}); .[$e] = ((.[$e] // []) + $add[$e])))' \
  ~/.claude/settings.json hook/hooks.json > /tmp/claude-settings.json && mv /tmp/claude-settings.json ~/.claude/settings.json
```

Run it once; running it again adds the hook twice. `jq` comes with macOS 15 and later; on older versions run `brew install jq` first.

## 5. Try it

Start a new Claude Code session and ask it anything. The puppet starts coding, and says "Done ✓" when Claude finishes.

To see ping pong, ask Claude for two subagents at once, for example: *"Use two subagents in parallel: one lists this folder, the other prints today's date."*

## Only for some commands

By default the puppet acts out every turn. To have it play only while some slash commands run, list them in `~/.hammerspoon/init.lua`, before the `start()` line:

```lua
hs.loadSpoon("ClaudePuppet")
spoon.ClaudePuppet.commands = { "code-review", "my-coding-skill" }
spoon.ClaudePuppet:start()
```

Then **Reload Config**. Other turns leave the puppet idle. `spoon.ClaudePuppet.pixel = 5` makes it bigger (the default is 4).

## Update

```sh
git -C ~/.claude-puppet/src pull
cp -R ~/.claude-puppet/src/ClaudePuppet.spoon ~/.hammerspoon/Spoons/
cp ~/.claude-puppet/src/hook/claude-puppet-hook.sh ~/.claude-puppet/hook.sh
```

Then **Reload Config** in Hammerspoon.

## Uninstall

```sh
cp ~/.claude/settings.json ~/.claude/settings.json.bak
jq '.hooks |= (with_entries(.value |= map(select(all(.hooks[]; .command | test("claude-puppet") | not)))) | with_entries(select(.value | length > 0)))' \
  ~/.claude/settings.json > /tmp/claude-settings.json && mv /tmp/claude-settings.json ~/.claude/settings.json
rm -rf ~/.hammerspoon/Spoons/ClaudePuppet.spoon ~/.claude-puppet
```

Then delete the two `ClaudePuppet` lines from `~/.hammerspoon/init.lua` and **Reload Config**. Hammerspoon itself stays; `brew uninstall --cask hammerspoon` removes it too.

## If the puppet does not move

- `tail -f ~/.claude-puppet/events` while Claude works: a line per event means the hook runs, and the problem is on the Hammerspoon side (open its Console from the menu bar icon to see errors).
- No lines: start a new Claude Code session, and check `/hooks` in Claude Code lists `~/.claude-puppet/hook.sh`.
