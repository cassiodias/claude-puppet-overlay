# claude-puppet-overlay

A Claude puppet that floats over your Mac desktop, like the old Office paperclip, and acts out what Claude Code is doing:

- **Idle:** sits at its desk, and dozes off after a while.
- **Claude is working:** codes at its laptop and shoots down an invader on its monitor with every tool call.
- **Subagents are running:** two puppets play ping pong, one per subagent, each scoring its own tool calls.
- **Claude needs you:** a speech bubble says so, like "Claude needs your permission to use Bash".
- **Done:** a "Done ✓" bubble when the turn and its subagents finish.

Drag it anywhere; it stays on top of every app and every desktop.

It is two small pieces: a Claude Code hook that writes one line per event to `~/.claude-puppet/events`, and a [Hammerspoon](https://www.hammerspoon.org) Spoon that reads them and draws the puppet. Nothing leaves your machine, and the only prompt text kept is a leading `/command`.

**[Install it (5 minutes)](INSTALL.md)**

Works on macOS with Hammerspoon. Pairs with the in-terminal mods [puppet-ping-pong](https://github.com/cassiodias/claude-ping-pong) and [puppet-coder](https://github.com/cassiodias/claude-coder), but needs neither.

## License

MIT
