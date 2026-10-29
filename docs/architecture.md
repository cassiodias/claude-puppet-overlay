# Architecture: from one file to components

Status: proposal. The puppets work today from one 969-line `ClaudePuppet.spoon/init.lua` and one hook script for
Claude Code. This splits the Spoon into small modules, so that new coding agents (Codex, Cursor, Antigravity,
OpenCode) can feed the same puppets, and new animations can be added without touching the rest.

## 1. Requirements

What it does:

- Reads agent events, keeps one session per agent conversation, and shows one puppet per busy session.
- Draws scenes (coder, Matrix, ping pong, rest, home) at 10 frames a second, with bubbles and name tags.
- Maps commands to animations from the menu bar, saved across restarts.
- Lets you click a puppet to reach its terminal tab, drag the row, move it between screens.

Non-functional:

- Never slows the agent: hooks only append a line and exit.
- Cheap: one Hammerspoon timer, at most a few puppets, a few hundred canvas rectangles a frame.
- Survives restarts: state is rebuilt from the events file.
- Safe to change: logic and drawing testable without Hammerspoon.

Constraints:

- Hammerspoon's Lua 5.4. The Spoon adds its `lib/` folder to `package.path` and loads modules as
  `require("puppet.model.sessions")`; the `puppet.` prefix keeps them apart from other Spoons' modules.
- Hooks are shell commands with JSON on stdin (Claude Code, Codex, Cursor, Antigravity); OpenCode needs a JS plugin.
- No dependencies beyond macOS (`plutil`, `jq` on macOS 15+) and Hammerspoon.

## 2. High-level design

Each coding agent is a **harness**: its own folder, behind one contract, tested on its own. Nothing outside a
harness folder knows which agent it is talking to.

```
  Claude Code ─► harnesses/claude/       ┐  each harness: hook registration, a translator
  Codex ───────► harnesses/codex/        │  (its payload → the common line), sample payloads
  Cursor ──────► harnesses/cursor/       ├─ with the lines they must produce, and a Lua module
  Antigravity ─► harnesses/antigravity/  │  (capabilities, look, how to reach its window)
  OpenCode ────► harnesses/opencode/     ┘
                         │  common line, written by write_event in hook/puppet-lib.sh (the only writer)
                         ▼
               ~/.claude-puppet/events      one line per event, agent named on each line
                         │
  ┌──────────────────────┼────────── ClaudePuppet.spoon ─────────────────────────────────┐
  │                      ▼                                                               │
  │   events/reader ──► events/parse ──► model/sessions ◄── model/mapping (menu choice)  │
  │   (tail, replay)    (line → Event)   (state per session,      │                      │
  │                                       "say" intents)          │                      │
  │                                            │                  │                      │
  │                                            ▼                  ▼                      │
  │                       render/scenes/* (pure: session → pixel buffer + texts)         │
  │                                            │                                         │
  │                                            ▼                                         │
  │   stage/stage (one canvas + bubble per puppet, layout, drag) ── terminals/* (focus)  │
  │   ui/menu (menu bar, dialogs)          init.lua (Spoon API: variables, start, stop)  │
  └──────────────────────────────────────────────────────────────────────────────────────┘
```

Dependency rule: arrows point one way. The core (`events`, `model`, `render`, `stage`, `ui`) depends on the harness
contract, never on a particular harness; harnesses depend only on the contract and the shared writer. `model/*`, `events/parse` and `render/*` never call `hs.*`; they get what
they need passed in. Only `events/reader`, `stage/*`, `terminals/*`, `ui/menu` and `init.lua` touch Hammerspoon.

## 3. Harnesses

### The contract

A harness has two halves: a folder `harnesses/<id>/` at the repo root (the hook side, which runs in the agent) and
one Lua file `ClaudePuppet.spoon/lib/puppet/harnesses/<id>.lua` (the Spoon side, which Hammerspoon loads):

| Part | File | Job |
| --- | --- | --- |
| Registration | `harnesses/<id>/hooks.json` (or `plugin.ts` for OpenCode) | tells the agent to call the translator on its events; the install step merges it into that agent's settings |
| Translator | `harnesses/<id>/translate.sh` | reads the agent's payload on stdin, maps its event and field names to the common line with the helpers in `hook/puppet-lib.sh`, prints whatever the agent needs to not block (`{}` for Cursor), exits 0 |
| Fixtures | `harnesses/<id>/fixtures/*.json` + `*.line` | payload samples from the agent's docs or a live run, and the exact line each must produce |
| Spoon module | `ClaudePuppet.spoon/lib/puppet/harnesses/<id>.lua` | the Lua side of the contract, below |

```lua
-- lib/puppet/harnesses/<id>.lua: what the Spoon may know about one agent, and nothing else.
return {
  id = "codex",                       -- the agent field on every line it writes
  name = "Codex",                     -- shown on name tags
  capabilities = {                    -- events this agent can send; scenes and menus adapt
    prompt = true, tools = true, toolFailure = false, subagents = true,
    permission = true, question = false, reply = false, sessionEnd = true,
  },
  character = { family = "#5B8DEF", accessory = "antenna" },  -- looks, no logos
  focus = function(session, terminals) ... end,               -- reach its window: a terminal tab for CLIs,
                                                              -- the app window for IDEs (Cursor, Antigravity)
}
```

Rules:

- **One writer.** Only `write_event` in `hook/puppet-lib.sh` writes `~/.claude-puppet/events`; translators never
  format lines themselves. The line format lives in two places only: that function and `events/parse.lua`.
- **Common vocabulary.** Translators emit Claude Code's event names (`UserPromptSubmit`, `PreToolUse`,
  `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `SubagentStart`, `SubagentStop`, `Notification`,
  `Stop`, `SessionEnd`), since it is the richest set; an agent that lacks one simply never sends it.
- **Capabilities, not checks.** Core code asks `harness.capabilities.permission`, never `agent == "cursor"`.
- **Registry.** `lib/puppet/harnesses/init.lua` lists the harnesses; the Spoon picks one per event by the line's agent field,
  and falls back to `claude` for old lines without it.

### What each harness covers today (from the research of 2026-10-29)

| | prompt | tools | tool failure | subagents | permission | reply text | session end | registration |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| claude | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | `~/.claude/settings.json` |
| codex | ✓ | ✓ | from the result | ✓ | ✓ | to confirm | ✓ | `~/.codex/hooks.json`, approve once in `/hooks` |
| cursor | ✓ | ✓ | ✓ | ✓ | ✗ | separate event | ✓ | `~/.cursor/hooks.json`, must print `{}` |
| antigravity | ✗ (no text) | ✓ | ✓ | ✗ | ✗ | transcript only | ✗ | `~/.gemini/config/hooks.json` |
| opencode | ✓ | ✓ | ✓ | child sessions | ✓ | from messages | partly | plugin in `~/.config/opencode/plugins/` |

### Testing a harness alone

- `tests/harnesses.sh` runs every `translate.sh` on every `fixtures/*.json` into a temporary events file and
  diffs it with the matching `.line`. No agent and no Hammerspoon needed; a new agent version is checked by
  dropping in new payload samples.
- `tests/harness_contract.lua` loads every Spoon-side harness module and checks it has the contract's fields and types.
- A fake harness (`tests/fake_harness.lua`) drives the model and scene tests, which proves the core does not
  depend on any real one.

## 4. Modules

| File | Owns | Today (lines in init.lua) | hs.* |
| --- | --- | --- | --- |
| `init.lua` | Spoon metadata, public variables (`coder`, `matrix`, `pingpong`, `conversation`, `pixel`, `eventsFile`), `start`/`stop`, the frame timer, wiring | 9-50, 926-969 | yes |
| `config.lua` | timings, palette, colours, key names for settings | 52-102 | no |
| `events/reader.lua` | tail the file, replay the last hours on start, offset and truncation | 774-787, replay in start | yes (`hs.fs`) |
| `events/parse.lua` | line → `Event` table; one place that knows the line format and its versions | `split`, top of `handle` | no |
| `model/sessions.lua` | the state machine: `apply(sessions, event, mapping, now)` → changes and intents like `{ say = sid, text = ..., seconds = 8 }` | 406-436, 590-680 | no |
| `model/mapping.lua` | command → animation lists, main conversation, `choiceFor`, `mappedScene`, parse typed lists, migrate old settings | 247-262, 682-772 | no (store passed in) |
| `render/pixels.lua` | buffer, `fill`, `stamp`, `toElements`, `bounce` | 152-205 | no |
| `render/text.lua` | `label`, `pill` | 206-240 | `hs.styledtext` only |
| `render/sprites.lua` | all sprite data | 104-150 | no |
| `render/scenes/desk.lua` | desk, laptop, puppet poses (typing, thinking, asking, permission, smile, rest) | 264-294, 356-365 | no |
| `render/scenes/monitor.lua` | the monitor frame; picks a screen: invaders, Matrix, reading lens, tests | 295-334 | no |
| `render/scenes/invaders.lua`, `matrix.lua` | one screen each | inside 295-354 | no |
| `render/scenes/pingpong.lua`, `home.lua` | one scene each | 367-404 | no |
| `stage/stage.lua` | which puppets show, their canvases, colours, layout, anchor, screens | 437-531, 889-925 | yes |
| `stage/bubble.lua` | bubble canvas, size, placement, timer | 449-465, 532-557 | yes |
| `terminals/focus.lua` | terminal apps table, focus a session | 86-97, 851-868 | yes |
| `terminals/iterm.lua` | tab map, tab label, select a tab | 789-850 | yes (`osascript`) |
| `ui/menu.lua` | menu items, edit dialogs, Option-click popup | 704-750 | yes |
| `harnesses/init.lua` | the registry: harness by agent id, `claude` as the default | none | no |
| `render/character.lua` | applies a harness's `character` (colour family, accessory) to a puppet | none | no |

About 60% of today's code lands in modules with no `hs.*` call.

## 5. Deep dive

### Event format v2

Today: `time|event|session|agent id|tool|agent type|text|folder|terminal|flag|tty`, Claude Code event names.

v2 adds the agent as the 12th field (`claude`, `codex`, `cursor`, `antigravity`, `opencode`) and keeps Claude Code's
event names as the common vocabulary: adapters translate theirs (`beforeSubmitPrompt` → `UserPromptSubmit`,
`BeforeTool` → `PreToolUse`, `stop` → `Stop`). A line with 11 fields is read as `claude`, so old lines still replay.

Trade-off, pipe line vs JSON lines:

| | Pipe line (keep) | JSON lines |
| --- | --- | --- |
| Writing from shell | `printf`, no escaping beyond `tr '|'` | needs `jq` or careful escaping in every adapter |
| Reading in Lua | `split` | `hs.json.decode`, slower per line, no real gain |
| Adding a field | append at the end, old lines still parse | free |
| Pick | **this one**, versioned by field count | revisit if a field ever needs structure |

### Session model

`model/sessions.lua` keeps today's fields (agents, order, score, mood, test, readingUntil, summary, command, tag,
tty, app, folder, seenAt, hasPlayed, isListed, isClosed) plus `agent`. It returns intents instead of calling
`say` itself, so replay (no bubbles) and tests need no special case:

```lua
local intents = Sessions.apply(state, event, mapping, now)
for _, intent in ipairs(intents) do stage:say(intent.sid, intent.text, intent.seconds) end
```

Capabilities differ per agent (Cursor has no permission event, Antigravity no subagents): the model does not care.
A missing event just means that mood never shows.

### Scenes as a small interface

Each scene is `{ draw = function(buf, texts, session, ctx) end }`, with `ctx = { frame, pixel, now, character }`.
`render/scenes/init.lua` picks one from `model` (`code` + monitor kind, `pingpong`, `rest`, `home`). A new
animation is one new file plus one row in the mapping list.

### Characters (for many agents)

Each harness's `character` gives a colour family and an optional accessory sprite (antenna, cap, headphones)
stamped over the same body; `render/character.lua` applies it. Several sessions of the same agent stay distinct by
shading within the family. No logos or brand mascots.

### Errors

- A line that does not parse is skipped, never fatal.
- A scene that errors draws nothing for that puppet that frame (`pcall` around each puppet's draw), so one bad
  scene cannot freeze the others; the error goes to the Hammerspoon Console once, not every frame.
- Adapters always exit 0 and print `{}`, so they can never block or slow an agent.

## 6. Scale and reliability

- Load: about 10 events a second at the busiest; the reader handles them in one pass per frame.
- Events file: capped at 1 MB by the hook; replay reads at most that.
- Puppets: realistic maximum 4-5; drawing cost grows linearly.
- Monitoring: the Hammerspoon Console; an optional `debug` flag that prints parse failures.

## 7. Testing

- Harnesses: fixture tests and the contract test, section 3.
- Pure modules run under plain Lua 5.4 (`brew install lua`) with a small test file per module in `tests/`, run by
  `tests/run.sh`. No Hammerspoon needed.
- Scene snapshots: each scene drawn to an ASCII grid for fixed frames and compared to saved snapshots, so a
  refactor that changes a pixel is visible.
- Before the split: record snapshots from today's single file, then require the split version to reproduce them
  byte for byte. That makes the refactor safe.

## 8. Migration plan

1. Add `tests/` with snapshot tests against today's `init.lua` (no behaviour change).
2. Extract the pure modules (`config`, `pixels`, `text`, `sprites`, scenes, `parse`, `mapping`, `sessions`); tests
   stay green.
3. Extract the Hammerspoon modules (`reader`, `stage`, `bubble`, `terminals`, `menu`); `init.lua` becomes wiring.
4. Event format v2 with the agent field, `hook/puppet-lib.sh` as the one writer, and the harness contract with
   `harnesses/claude/` as its first implementation (today's hook, now a translator with fixtures).
5. Add `harnesses/codex/`, then `cursor`, `opencode`, `antigravity`, each with fixtures from a real run first.
6. Decide on the name: `claude-puppet-overlay` and `ClaudePuppet` would mislead once other agents work. Renaming
   the Spoon changes install paths, so it ships with a note in INSTALL.md's Update section.

## 9. What to revisit as it grows

- More than one events file (one per agent) if adapters start to conflict on writes.
- JSON lines if a field needs structure (a list of modified files, for example).
- A plugin-style scene registry if people want to add their own animations without editing the Spoon.
