# claude-puppet-overlay

Claude puppets that float over your Mac desktop, like the old Office paperclip, and act out what Claude Code is doing: one puppet per busy Claude session.

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

- **One puppet per session:** with one tab coding and another reviewing, two puppets sit side by side, each in its own colour, with a name tag (the command you ran, or the project folder), its own scene and its own bubble. Between turns a puppet rests at its desk with the monitor off, and dozes; it leaves when its session ends or its iTerm tab closes. With no session on stage, one puppet waits at home.
- **Pick the commands that play, and their scene,** from the `▟▙` menu bar icon (or Option-click a puppet): tick `my-coding-skill` as Coder and `my-reviewer` as Ping pong, and only turns running them get a show, in whichever tab runs them.
- **Click a puppet** (or its bubble) to jump to the terminal running that session. In iTerm2 it selects the exact window and tab, and the tab number is written under the puppet's table (`tab 3`, or `window 2 · tab 3` with several windows).
- **Drag any puppet** to move the whole row, across screens too; it stays on top of every app and every desktop. The `▟▙` menu bar icon sends the row to the corner of any screen, and puppets left on a screen you unplug come back to the main one.

It is two small pieces: a Claude Code hook that writes one line per event to `~/.claude-puppet/events`, and a [Hammerspoon](https://www.hammerspoon.org) Spoon that reads them and draws the puppet. Nothing leaves your machine. From your prompts it keeps only a leading `/command`; from Claude's answers, only the first sentence; never commands or code.

**[Install it (5 minutes)](INSTALL.md)**

Works on macOS with Hammerspoon. Pairs with the in-terminal mods [puppet-ping-pong](https://github.com/cassiodias/claude-ping-pong) and [puppet-coder](https://github.com/cassiodias/claude-coder), but needs neither.

## License

MIT
