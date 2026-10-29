--- === ClaudePuppet ===
---
--- Claude puppets that float over your desktop, one per busy Claude Code session, acting out what it is doing:
--- it thinks, codes at its laptop, reads, runs tests, plays ping pong while subagents run,
--- raises a hand when Claude asks you something, and says what Claude did when it is done.
--- Click a puppet to jump to its session's terminal.
---
--- Claude Code hooks append one line per event to `~/.claude-puppet/events`; this Spoon reads it.

local obj = {}
obj.__index = obj

obj.name = "ClaudePuppet"
obj.version = "0.4.1"
obj.author = "Cassio Dias"
obj.license = "MIT - https://opensource.org/licenses/MIT"
obj.homepage = "https://github.com/cassiodias/claude-puppet-overlay"

--- ClaudePuppet.commands
--- Variable
--- Slash commands that play a scene, without the slash; empty plays one for every turn.
obj.commands = {}

--- ClaudePuppet.pixel
--- Variable
--- Size of one puppet pixel, in screen points.
obj.pixel = 4

--- ClaudePuppet.eventsFile
--- Variable
--- The file the Claude Code hook appends events to.
obj.eventsFile = os.getenv("HOME") .. "/.claude-puppet/events"

local W, H = 48, 24
local FPS = 10
local IDLE_SLEEP_SECONDS = 30
local DONE_SECONDS = 8
local LEAVE_SECONDS = 3 * 60
local GAP = 12
-- Each busy session's puppet takes the first colour no other puppet is wearing.
local PALETTE = { "#D97757", "#5B8DEF", "#A06CD5", "#4FB286", "#E0A43B" }
local CLICK_DISTANCE = 4
local POSITION_KEY = "ClaudePuppet.position"

local COLORS = {
  c = { hex = "#D97757" }, -- the puppet
  d = { hex = "#8C8C8C" }, -- a puppet whose subagent is done
  k = { hex = "#1E1E1E" }, -- eyes
  g = { hex = "#D0D0D0" }, -- laptop and monitor
  s = { hex = "#15181E" }, -- monitor screen
  v = { hex = "#8FD18B" }, -- invaders
  w = { hex = "#F2F2F2" }, -- shot, ball, net
  y = { hex = "#F2C14E" }, -- explosion
  b = { hex = "#8A6A4F" }, -- desk
  t = { hex = "#2E6B4F" }, -- ping pong table
  p = { hex = "#6BBF59" }, -- tests passed
  r = { hex = "#E5534B" }, -- tests failed
}

-- Terminal apps by the TERM_PROGRAM the hook saw, so a click can bring the session's window forward.
local TERMINALS = {
  ["iTerm.app"] = "com.googlecode.iterm2",
  Apple_Terminal = "com.apple.Terminal",
  ghostty = "com.mitchellh.ghostty",
  WezTerm = "com.github.wez.wezterm",
  WarpTerminal = "dev.warp.Warp-Stable",
  vscode = "com.microsoft.VSCode",
  Hyper = "co.zeit.hyper",
  Tabby = "org.tabby",
  zed = "dev.zed.Zed",
}

local ITERM = "com.googlecode.iterm2"
local TABS_SECONDS = 3

local READING_TOOLS = { Read = true, Grep = true, Glob = true, LSP = true, WebFetch = true, WebSearch = true }

local SIDE = {
  "..ccccc..",
  ".ccccccc.",
  ".cccccck.",
  ".cccccck.",
  ".ccccccc.",
  ".ccccccc.",
  ".ccccccc.",
  ".ccccccc.",
  ".ccccccc.",
}

local SMILE = {
  "..ccccc..",
  ".ccccccc.",
  ".ckccckc.",
  ".ckccckc.",
  ".ccccccc.",
  ".kccccck.",
  ".ckkkkkc.",
  ".ccccccc.",
  ".ccccccc.",
}

local FRONT = {
  ".ccccccc.",
  ".ckcccck.",
  "ccccccccc",
  ".ccccccc.",
  ".c.c.c.c.",
}

local FRONT_ASLEEP = {
  ".ccccccc.",
  ".cccccccc",
  "ccccccccc",
  ".ccccccc.",
  ".c.c.c.c.",
}

local INVADER = { { ".vvv.", "v.v.v", "v...v" }, { ".vvv.", "v.v.v", ".v.v." } }
local SHIP = { "..c..", "ccccc" }
local BOOM = { "y.y.y", ".y.y.", "y.y.y" }
local WAVE_ORDER = { 3, 1, 4, 2 }
local CHECK = { "......p", ".....p.", "p...p..", ".p.p...", "..p...." }
local CROSS = { "r...r", ".r.r.", "..r..", ".r.r.", "r...r" }
local LENS = { ".www..", "w...w.", "w...w.", ".www..", "....g.", ".....g" }

local function bounce(n, span)
  if span <= 0 then return 0 end
  local p = n % (2 * span)
  return p < span and p or 2 * span - p
end

local function newBuffer()
  local buf = {}
  for y = 0, H - 1 do buf[y] = {} end
  return buf
end

local function fill(buf, x1, y1, x2, y2, key)
  for y = math.max(0, y1), math.min(H - 1, y2) do
    for x = math.max(0, x1), math.min(W - 1, x2) do buf[y][x] = key end
  end
end

-- Draws a sprite with its top left at x, y; `recolor` swaps the puppet's colour (a finished subagent).
local function stamp(buf, sprite, x, y, recolor)
  for row, line in ipairs(sprite) do
    for col = 1, #line do
      local key = line:sub(col, col)
      if key ~= "." then
        if recolor and key == "c" then key = recolor end
        fill(buf, x + col - 1, y + row - 1, x + col - 1, y + row - 1, key)
      end
    end
  end
end

-- Turns the pixel buffer into canvas rectangles, one per run of a colour on a row, in a puppet's colours.
local function toElements(buf, px, colors)
  local elements = {}
  for y = 0, H - 1 do
    local x = 0
    while x < W do
      local key = buf[y][x]
      if key then
        local run = x
        while run + 1 < W and buf[y][run + 1] == key do run = run + 1 end
        elements[#elements + 1] = {
          type = "rectangle", action = "fill", fillColor = colors[key],
          frame = { x = x * px, y = y * px, w = (run - x + 1) * px, h = px },
        }
        x = run + 1
      else
        x = x + 1
      end
    end
  end
  return elements
end

-- Text on the puppet: white with a black outline, readable on dark and light desktops alike; dark on the sign.
local function label(text, x, y, w, align, px, isDark)
  local style = {
    font = { name = "Menlo-Bold", size = 2.5 * px },
    color = { white = isDark and 0.1 or 1 },
    paragraphStyle = { alignment = align },
  }
  if not isDark then style.strokeColor, style.strokeWidth = { white = 0 }, -5 end
  return {
    type = "text", text = hs.styledtext.new(text, style),
    frame = { x = x * px, y = y * px, w = w * px, h = 4 * px },
  }
end

local function colorsFor(hex)
  local colors = {}
  for key, color in pairs(COLORS) do colors[key] = color end
  colors.c = { hex = hex }
  return colors
end

local function split(line)
  local fields = {}
  for value in (line .. "|"):gmatch("([^|]*)|") do fields[#fields + 1] = value end
  return fields
end

local function isListed(commands, command)
  if #commands == 0 then return true end
  local name = (command or ""):gsub("^/", "")
  for _, listed in ipairs(commands) do
    if listed:gsub("^/", "") == name then return true end
  end
  return false
end

-- The puppet's pose at the desk: typing, thinking, a raised hand, a sign asking for permission,
-- and now and then a turn to smile at you.
function obj:drawPuppet(buf, texts, s)
  local frame, px = self.frame, self.pixel
  local isSmiling = s.mood == nil and frame % 80 >= 68
  stamp(buf, isSmiling and SMILE or SIDE, 1, 10)
  if s.mood == "thinking" then
    fill(buf, 9, 14, 9, 15, "c")
    fill(buf, 10, 8, 10, 8, "w")
    fill(buf, 11, 6, 12, 6, "w")
    texts[#texts + 1] = label(string.rep(".", frame // 4 % 3 + 1), 11, 1, 8, "left", px)
  elseif s.mood == "asking" then
    fill(buf, 9, 6, 9, 11, "c")
    fill(buf, 8, 4, 10, 5, "c")
  elseif s.mood == "permission" then
    fill(buf, 9, 7, 9, 11, "b")
    fill(buf, 1, 1, 15, 6, "w")
    texts[#texts + 1] = label(s.moodText .. "?", 1, 1.5, 15, "center", px, true)
  elseif not isSmiling and frame // 2 % 2 == 0 then
    fill(buf, 9, 16, 10, 16, "c")
  end
end

-- The monitor: invaders it shoots with each tool call, a lens while it reads, a progress bar while tests run.
function obj:drawMonitor(buf, texts, s)
  local frame, px = self.frame, self.pixel
  fill(buf, 17, 1, W - 2, 18, "g")
  fill(buf, 18, 2, W - 3, 17, "s")
  texts[#texts + 1] = label(string.format("%05d", s.score), 30, 1.5, 15, "right", px)
  if s.test and s.test.state == "running" then
    fill(buf, 21, 9, 42, 10, "g")
    fill(buf, 21, 9, 21 + frame // 2 % 22, 10, "y")
    texts[#texts + 1] = label("tests", 18, 11.5, 28, "center", px)
    return
  end
  if s.test and frame < s.test.untilFrame then
    stamp(buf, s.test.state == "pass" and CHECK or CROSS, 29, 7)
    return
  end
  if frame < s.readingUntil then
    stamp(buf, LENS, 19 + bounce(frame, 20), 6)
    return
  end
  local march = bounce(frame // 5, 3)
  local at = function(slot) return 19 + march + (slot - 1) * 6 end
  local killed = s.score % #WAVE_ORDER
  local target = s.score > 0 and WAVE_ORDER[(s.score - 1) % #WAVE_ORDER + 1] or nil
  local age = frame - s.tappedAt
  local isShooting = target ~= nil and age < 8
  local legs = INVADER[(frame // 3) % 2 + 1]
  for i = killed + 1, #WAVE_ORDER do stamp(buf, legs, at(WAVE_ORDER[i]), 5) end
  if isShooting and age < 4 then stamp(buf, legs, at(target), 5) end
  if isShooting and age >= 4 then stamp(buf, BOOM, at(target), 5) end
  local ship = isShooting and at(target) or 19 + bounce(frame // 2, 21)
  if isShooting and age < 4 then fill(buf, ship + 2, 13 - age * 2, ship + 2, 14 - age * 2, "w") end
  stamp(buf, SHIP, ship, 15)
end

-- The puppet at its desk, with a small `_|` laptop under its paws and a monitor.
function obj:drawCode(buf, texts, s)
  fill(buf, 0, 19, W - 1, 20, "b")
  fill(buf, 2, 21, 3, H - 1, "b")
  fill(buf, W - 4, 21, W - 3, H - 1, "b")
  fill(buf, 9, 17, 14, 17, "g")
  fill(buf, 14, 11, 14, 17, "g")
  self:drawPuppet(buf, texts, s)
  self:drawMonitor(buf, texts, s)
end

-- Two puppets rally over a table; each seat is one of the turn's first two subagents, scoring its tool calls.
function obj:drawPingPong(buf, texts, s)
  local frame, px = self.frame, self.pixel
  local left, right = s.agents[s.order[1]], s.agents[s.order[2]]
  fill(buf, 10, 17, W - 11, 18, "t")
  fill(buf, 12, 19, 12, H - 1, "g")
  fill(buf, W - 13, 19, W - 13, H - 1, "g")
  fill(buf, W // 2, 14, W // 2, 16, "w")
  stamp(buf, FRONT, 0, 13, left.done and "d" or nil)
  stamp(buf, FRONT, W - 9, 13, right.done and "d" or nil)
  if not left.done then fill(buf, 9, 13, 9, 15, "w") end
  if not right.done then fill(buf, W - 10, 13, W - 10, 15, "w") end

  local span = W - 22
  local p = frame % (2 * span)
  local x = p < span and p or 2 * span - p
  local y = 15 - math.floor(7 * math.sin(math.pi * x / span) + 0.5)
  fill(buf, 11 + x, y, 11 + x, y, "w")

  texts[#texts + 1] = label(left.label .. " " .. left.hits .. (left.done and " ✓" or ""), 0, 2, 22, "left", px)
  texts[#texts + 1] = label(right.label .. " " .. right.hits .. (right.done and " ✓" or ""), W - 22, 2, 22, "right", px)
end

-- The puppet waits at its desk, and dozes off after a while.
function obj:drawIdle(buf, texts, s)
  local px = self.pixel
  fill(buf, 0, 19, W - 1, 20, "b")
  fill(buf, 2, 21, 3, H - 1, "b")
  fill(buf, W - 4, 21, W - 3, H - 1, "b")
  local isAsleep = os.time() - (s and s.seenAt or self.lastEventAt) > IDLE_SLEEP_SECONDS
  stamp(buf, isAsleep and FRONT_ASLEEP or FRONT, 19, 14)
  if isAsleep then
    local rise = (self.frame // 5) % 4
    texts[#texts + 1] = label("z", 29 + rise, 11 - rise, 4, "left", px)
  end
end

local function liveAgents(s)
  local live = 0
  for _, id in ipairs(s.order) do
    if not s.agents[id].done then live = live + 1 end
  end
  return live
end

local function sceneFor(s)
  local live = liveAgents(s)
  if s.mood == "asking" or s.mood == "permission" then return "code" end
  if #s.order >= 2 and live > 0 then return "pingpong" end
  if s.isWorking or live > 0 then return "code" end
  return "idle"
end

-- A session keeps its puppet while it works, needs you or was busy in the last few minutes.
local function isOnStage(s)
  return s.isListed and (s.isWorking or s.mood ~= nil or liveAgents(s) > 0 or os.time() - s.seenAt < LEAVE_SECONDS)
end

-- The puppets to show, oldest session first; one puppet waits at home when no session is busy.
function obj:stageKeys()
  local keys = {}
  for sid, s in pairs(self.sessions) do
    if isOnStage(s) then keys[#keys + 1] = sid end
  end
  table.sort(keys, function(a, b) return self.sessions[a].joinedAt < self.sessions[b].joinedAt end)
  if #keys == 0 then keys = { "home" } end
  return keys
end

local BUBBLE_HEIGHT, BUBBLE_GAP, SCREEN_MARGIN = 34, 6, 8

-- Places a puppet's bubble above it, right edges lined up, kept inside the screen the puppet is on
-- (below the puppet when there is no room above).
function obj:bubbleFrame(puppet, width)
  local top, puppetWidth, puppetHeight = puppet.canvas:topLeft(), W * self.pixel, H * self.pixel
  local center = { x = top.x + puppetWidth / 2, y = top.y + puppetHeight / 2 }
  local screen = hs.screen.mainScreen():frame()
  for _, each in ipairs(hs.screen.allScreens()) do
    local f = each:frame()
    if center.x >= f.x and center.x < f.x + f.w and center.y >= f.y and center.y < f.y + f.h then screen = f end
  end
  local x = top.x + puppetWidth - width
  x = math.max(screen.x + SCREEN_MARGIN, math.min(x, screen.x + screen.w - width - SCREEN_MARGIN))
  local y = top.y - BUBBLE_HEIGHT - BUBBLE_GAP
  if y < screen.y + SCREEN_MARGIN then y = top.y + puppetHeight + BUBBLE_GAP end
  return { x = x, y = y, w = width, h = BUBBLE_HEIGHT }
end

local function floating(canvas)
  canvas:level(hs.canvas.windowLevels.floating)
  canvas:behavior({ "canJoinAllSpaces", "stationary" })
  canvas:clickActivating(false)
  canvas:canvasMouseEvents(true, false, false, false)
  return canvas
end

-- A new puppet and its bubble for a session, in the first free colour.
function obj:newPuppet(key)
  local used = {}
  for _, puppet in pairs(self.stage) do used[puppet.color] = true end
  local color = PALETTE[1]
  for _, hex in ipairs(PALETTE) do
    if not used[hex] then
      color = hex
      break
    end
  end
  local canvas = floating(hs.canvas.new({ x = self.anchor.x, y = self.anchor.y, w = W * self.pixel, h = H * self.pixel }))
  canvas:mouseCallback(function(_, message)
    if message == "mouseDown" then self:startDrag(key) end
  end)
  local bubble = floating(hs.canvas.new({ x = self.anchor.x, y = self.anchor.y - 40, w = 200, h = BUBBLE_HEIGHT }))
  bubble:mouseCallback(function(_, message)
    if message == "mouseDown" then self:focus(key) end
  end)
  local puppet = { canvas = canvas, bubble = bubble, color = color, colors = colorsFor(color) }
  self.stage[key] = puppet
  return puppet
end

function obj:removePuppet(key)
  local puppet = self.stage[key]
  if puppet.bubbleTimer then puppet.bubbleTimer:stop() end
  puppet.canvas:delete()
  puppet.bubble:delete()
  self.stage[key] = nil
end

-- Lines the puppets up leftwards from the anchor: one per session on stage, puppets of quiet sessions leave.
function obj:layout()
  local keys = self:stageKeys()
  local wanted = {}
  for _, key in ipairs(keys) do wanted[key] = true end
  for key in pairs(self.stage) do
    if not wanted[key] then self:removePuppet(key) end
  end
  for i, key in ipairs(keys) do
    local puppet = self.stage[key] or self:newPuppet(key)
    puppet.canvas:topLeft({ x = self.anchor.x - (i - 1) * (W * self.pixel + GAP), y = self.anchor.y })
    if self.isShown then puppet.canvas:show() end
    if puppet.bubble:isShowing() then puppet.bubble:frame(self:bubbleFrame(puppet, puppet.bubble:frame().w)) end
  end
  self.keys = keys
end

function obj:render()
  self.frame = self.frame + 1
  self:layout()
  for _, key in ipairs(self.keys) do
    local puppet, s = self.stage[key], self.sessions[key]
    local buf, texts = newBuffer(), {}
    local scene = s and sceneFor(s) or "idle"
    if scene == "pingpong" then self:drawPingPong(buf, texts, s)
    elseif scene == "code" then self:drawCode(buf, texts, s)
    else self:drawIdle(buf, texts, s) end
    if s then
      texts[#texts + 1] = label(s.tag, 0, 18.6, W, "center", self.pixel)
      local tab = self:tabLabel(s)
      if tab then texts[#texts + 1] = label(tab, 0, 21.2, W, "center", self.pixel) end
    end
    local elements = toElements(buf, self.pixel, puppet.colors)
    for _, text in ipairs(texts) do elements[#elements + 1] = text end
    puppet.canvas:replaceElements(elements)
  end
end

--- ClaudePuppet:say(key, text, seconds)
--- Method
--- Shows a speech bubble above a session's puppet; it stays until the next event, or for `seconds` when given.
function obj:say(key, text, seconds)
  local puppet = self.stage[key]
  if not puppet and text and text ~= "" then
    self:layout()
    puppet = self.stage[key]
  end
  if not puppet then return end
  if puppet.bubbleTimer then
    puppet.bubbleTimer:stop()
    puppet.bubbleTimer = nil
  end
  if not text or text == "" then
    puppet.bubble:hide()
    return
  end
  local width = math.min(340, 7 * (utf8.len(text) or #text) + 24)
  puppet.bubble:frame(self:bubbleFrame(puppet, width))
  puppet.bubble:replaceElements({
    { type = "rectangle", action = "strokeAndFill", fillColor = { white = 1, alpha = 0.95 },
      strokeColor = { hex = puppet.color }, strokeWidth = 2, roundedRectRadii = { xRadius = 10, yRadius = 10 } },
    { type = "text", text = text, textColor = { white = 0.1 }, textSize = 12,
      frame = { x = 12, y = 8, w = width - 24, h = 20 } },
  })
  if self.isShown then puppet.bubble:show() end
  if seconds then puppet.bubbleTimer = hs.timer.doAfter(seconds, function() self:say(key, nil) end) end
end

-- Ends the turn's show once the main thread and every subagent are done, saying what Claude did.
function obj:finish(sid, s)
  if s.isListed and not s.isWorking and liveAgents(s) == 0 then
    self:say(sid, (s.summary ~= "" and s.summary or "Done") .. " ✓", DONE_SECONDS)
  end
end

-- Applies one hook event line to its session.
function obj:handle(line)
  local f = split(line)
  local event, sid, aid, tool, atype, text, folder, app, flag, tty =
    f[2], f[3] or "", f[4] or "", f[5] or "", f[6] or "", f[7] or "", f[8] or "", f[9] or "", f[10] or "", f[11] or ""
  if not event or sid == "" then return end
  if event == "SessionEnd" then
    self.sessions[sid] = nil
    return
  end
  local s = self.sessions[sid]
  if not s then
    self.joined = self.joined + 1
    s = {
      agents = {}, order = {}, score = 0, isWorking = false, readingUntil = 0, summary = "", tappedAt = -100,
      joinedAt = self.joined, folder = "", tag = "",
      -- A session first seen mid-turn has no prompt to judge by: it plays unless a commands list is set.
      isListed = #self.commands == 0,
    }
    self.sessions[sid] = s
  end
  self.lastEventAt = os.time()
  s.seenAt = os.time()
  if folder ~= "" then s.folder = folder end
  if app ~= "" then s.app = app end
  if tty:match("^/dev/ttys%d+$") then s.tty = tty end
  if s.tag == "" then s.tag = s.folder end

  if event == "UserPromptSubmit" then
    s.agents, s.order, s.score, s.isWorking, s.test, s.summary = {}, {}, 0, true, nil, ""
    s.isListed = isListed(self.commands, text)
    s.tag = text ~= "" and text:gsub("^/", "") or s.folder
    s.mood = "thinking"
    self:say(sid, nil)
  elseif event == "PreToolUse" then
    if aid ~= "" and s.agents[aid] then s.agents[aid].hits = s.agents[aid].hits + 1 end
    -- Claude calling a listed skill starts the show mid-turn, as typing its /command does.
    if tool == "Skill" and #self.commands > 0 and isListed(self.commands, text) then
      s.isListed, s.tag = true, text
    end
    if aid == "" then
      s.isWorking = true
      s.mood = nil
      if tool == "AskUserQuestion" then s.mood, s.moodText = "asking", "I have a question for you" end
      if tool == "ExitPlanMode" then s.mood, s.moodText = "asking", "Plan ready for you" end
    end
    if s.mood == "asking" and s.isListed then self:say(sid, s.moodText) else self:say(sid, nil) end
    if READING_TOOLS[tool] then
      s.readingUntil = self.frame + 20
    elseif flag == "test" then
      s.test = { state = "running" }
    else
      s.score = s.score + 1
      s.tappedAt = self.frame
    end
  elseif event == "PostToolUse" or event == "PostToolUseFailure" then
    if flag == "test" and s.test then
      s.test = { state = event == "PostToolUse" and "pass" or "fail", untilFrame = self.frame + 30 }
    end
    if s.mood == "permission" or s.mood == "asking" then
      s.mood = nil
      self:say(sid, nil)
    end
  elseif event == "PermissionRequest" then
    s.mood, s.moodText = "permission", (tool ~= "" and tool or "OK")
    if s.isListed then self:say(sid, "May I use " .. s.moodText .. "?") end
  elseif event == "SubagentStart" and aid ~= "" then
    s.agents[aid] = { label = (atype ~= "" and atype or "agent"):sub(1, 18), hits = 0, done = false }
    s.order[#s.order + 1] = aid
  elseif event == "SubagentStop" and s.agents[aid] then
    s.agents[aid].done = true
    self:finish(sid, s)
  elseif event == "Notification" then
    local isShown = s.mood == "permission" or s.mood == "asking"
    if s.isListed and not isShown then self:say(sid, text ~= "" and text or "Claude needs you") end
  elseif event == "Stop" then
    s.isWorking, s.mood, s.summary = false, nil, text
    -- Background subagents may still be working; the last one to stop says it then.
    self:finish(sid, s)
  end
end

-- Reads the lines the hook appended since the last read; a file that shrank was emptied, so it starts over.
function obj:readEvents()
  local size = hs.fs.attributes(self.eventsFile, "size")
  if not size or size == self.offset then return end
  if size < self.offset then self.offset = 0 end
  local file = io.open(self.eventsFile, "r")
  if not file then return end
  file:seek("set", self.offset)
  local data = file:read("a") or ""
  file:close()
  local complete = data:match("^(.*\n)") or ""
  self.offset = self.offset + #complete
  for line in complete:gmatch("([^\n]*)\n") do self:handle(line) end
end

-- Asks iTerm which window and tab holds each terminal device; only while iTerm runs, so it is never launched.
function obj:refreshTabs()
  self.tabs, self.iTermWindows = {}, 0
  if not hs.application.get(ITERM) then return end
  local ok, result = hs.osascript.applescript([[
    set out to ""
    tell application id "com.googlecode.iterm2"
      set wi to 0
      repeat with w in windows
        set wi to wi + 1
        set ti to 0
        repeat with t in tabs of w
          set ti to ti + 1
          repeat with s in sessions of t
            set out to out & (tty of s) & "=" & wi & "/" & ti & ";"
          end repeat
        end repeat
      end repeat
    end tell
    return out]])
  if not ok or type(result) ~= "string" then return end
  for tty, window, tab in result:gmatch("([^=;]+)=(%d+)/(%d+);") do
    self.tabs[tty] = { window = tonumber(window), tab = tonumber(tab) }
    self.iTermWindows = math.max(self.iTermWindows, tonumber(window))
  end
end

-- The iTerm tab a session runs in, as shown under its table; the window too when iTerm has several.
function obj:tabLabel(s)
  local place = s.tty and self.tabs[s.tty]
  if not place then return nil end
  if self.iTermWindows > 1 then return "window " .. place.window .. " · tab " .. place.tab end
  return "tab " .. place.tab
end

-- Selects the iTerm window, tab and pane running a terminal device; false when iTerm has none.
local function selectITermSession(tty)
  local ok, found = hs.osascript.applescript(string.format([[
    tell application id "com.googlecode.iterm2"
      repeat with w in windows
        repeat with t in tabs of w
          repeat with s in sessions of t
            if tty of s is "%s" then
              select w
              select t
              select s
              activate
              return true
            end if
          end repeat
        end repeat
      end repeat
    end tell
    return false]], tty))
  return ok and found == true
end

-- Brings forward the terminal running a session: its exact iTerm tab when known, otherwise the app
-- and the window whose title names the folder.
function obj:focus(key)
  local s = self.sessions[key]
  if s and s.app == "iTerm.app" and s.tty and selectITermSession(s.tty) then return end
  local bundle = s and TERMINALS[s.app or ""]
  if not bundle then return end
  hs.application.launchOrFocusByBundleID(bundle)
  local app = hs.application.get(bundle)
  if not app or s.folder == "" then return end
  for _, win in ipairs(app:allWindows()) do
    if (win:title() or ""):find(s.folder, 1, true) then
      win:focus()
      return
    end
  end
end

-- Dragging any puppet moves the whole row, and the place is remembered; a click without a drag is a focus.
function obj:startDrag(key)
  local start = hs.mouse.absolutePosition()
  local origin = { x = self.anchor.x, y = self.anchor.y }
  local types = hs.eventtap.event.types
  self.dragTap = hs.eventtap.new({ types.leftMouseDragged, types.leftMouseUp }, function(e)
    local now = hs.mouse.absolutePosition()
    self.anchor = { x = origin.x + now.x - start.x, y = origin.y + now.y - start.y }
    self:layout()
    if e:getType() == types.leftMouseUp then
      self.dragTap:stop()
      self.dragTap = nil
      hs.settings.set(POSITION_KEY, self.anchor)
      if math.abs(now.x - start.x) + math.abs(now.y - start.y) < CLICK_DISTANCE then self:focus(key) end
    end
    return false
  end)
  self.dragTap:start()
end

function obj:defaultPosition()
  local screen = hs.screen.mainScreen():frame()
  return { x = screen.x + screen.w - W * self.pixel - 40, y = screen.y + screen.h - H * self.pixel - 40 }
end

function obj:toggle()
  self.isShown = not self.isShown
  for _, puppet in pairs(self.stage) do
    if self.isShown then
      puppet.canvas:show()
    else
      puppet.canvas:hide()
      puppet.bubble:hide()
    end
  end
end

--- ClaudePuppet:start()
--- Method
--- Shows the puppets and starts following Claude Code's events.
function obj:start()
  self.anchor = hs.settings.get(POSITION_KEY) or self:defaultPosition()
  self.frame, self.lastEventAt, self.joined, self.isShown = 0, os.time(), 0, true
  self.sessions, self.stage, self.keys, self.tabs, self.iTermWindows = {}, {}, {}, {}, 0
  self.offset = hs.fs.attributes(self.eventsFile, "size") or 0

  self.menu = hs.menubar.new()
  self.menu:setTitle("▟▙")
  self.menu:setMenu(function()
    return {
      { title = self.isShown and "Hide puppets" or "Show puppets", fn = function() self:toggle() end },
      { title = "Move to corner", fn = function()
        hs.settings.clear(POSITION_KEY)
        self.anchor = self:defaultPosition()
        self:layout()
      end },
    }
  end)

  self.timer = hs.timer.doEvery(1 / FPS, function()
    self:readEvents()
    self:render()
  end)
  self.tabsTimer = hs.timer.doEvery(TABS_SECONDS, function() self:refreshTabs() end)
  self:refreshTabs()
  self:render()
  return self
end

--- ClaudePuppet:stop()
--- Method
--- Hides the puppets and stops following events.
function obj:stop()
  if self.timer then self.timer:stop() end
  if self.tabsTimer then self.tabsTimer:stop() end
  if self.dragTap then self.dragTap:stop() end
  if self.menu then self.menu:delete() end
  for key in pairs(self.stage or {}) do self:removePuppet(key) end
  self.timer, self.tabsTimer, self.dragTap, self.menu = nil, nil, nil, nil
  return self
end

return obj
