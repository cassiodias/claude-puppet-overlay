# claude-puppet-overlay

A Claude puppet that floats over your Mac desktop, like the old Office paperclip, and acts out what Claude Code is doing.

| When Claude is... | The puppet... |
| --- | --- |
| reading your prompt | rests its chin on its paw, with a thought bubble |
| working | types on its laptop and shoots an invader on its monitor with every tool call; now and then it turns to smile at you |
| reading or searching files | moves a magnifying glass over the monitor |
| running tests | shows a progress bar, then a green ✓ or a red ✗ |
| running subagents | plays ping pong: two puppets, one per subagent, each scoring its own tool calls |
| asking you something or showing a plan | raises its hand: "I have a question for you", "Plan ready for you" |
| waiting for a permission | holds up a sign with the tool's name: "May I use Bash?" |
| done | says the first sentence of Claude's answer, like "Fixed the parser and added two tests. ✓" |
| idle | waits at its desk, and dozes off after a while |

- **Click the puppet** (or its bubble) to jump to the terminal running that Claude session.
- **Drag it** anywhere; it stays on top of every app and every desktop.
- **Several Claude sessions?** Bubbles name the project folder, like `[my-app] May I use Bash?`.

It is two small pieces: a Claude Code hook that writes one line per event to `~/.claude-puppet/events`, and a [Hammerspoon](https://www.hammerspoon.org) Spoon that reads them and draws the puppet. Nothing leaves your machine. From your prompts it keeps only a leading `/command`; from Claude's answers, only the first sentence; never commands or code.

**[Install it (5 minutes)](INSTALL.md)**

Works on macOS with Hammerspoon. Pairs with the in-terminal mods [puppet-ping-pong](https://github.com/cassiodias/claude-ping-pong) and [puppet-coder](https://github.com/cassiodias/claude-coder), but needs neither.

## License

MIT
