-- What a session is doing, in words: the short line under the name tag, and the card shown when the mouse
-- rests on its puppet.

local status = {}

local REPLY_CHARS = 45

-- 45 seconds → "<1m", 32 minutes → "32m", 65 minutes → "1h 5m".
local function duration(seconds)
  local minutes = math.floor(math.max(0, seconds) / 60)
  if minutes < 1 then return "<1m" end
  if minutes < 60 then return minutes .. "m" end
  return math.floor(minutes / 60) .. "h " .. (minutes % 60) .. "m"
end

local function agentCounts(s)
  local live, done = 0, 0
  for _, agent in pairs(s.agents) do
    if agent.done then done = done + 1 else live = live + 1 end
  end
  return live, done
end

local function isWaiting(s) return s.mood == "permission" or s.mood == "asking" end
local function isWorking(s) return s.isWorking or agentCounts(s) > 0 end

-- "32m", "waiting 3m" or "idle 12m": how long the session has been in its state.
local function since(s, now)
  if isWaiting(s) then return "waiting " .. duration(now - s.seenAt) end
  if isWorking(s) then return duration(now - (s.turnAt or s.seenAt)) end
  return "idle " .. duration(now - s.seenAt)
end

local function shorten(text, chars)
  if (utf8.len(text) or #text) <= chars then return text end
  return text:sub(1, (utf8.offset(text, chars + 1) or chars + 1) - 1):gsub("%s+$", "") .. "…"
end

-- The line under the name tag: the folder, unless the tag already shows it, and the time.
function status.line(s, now)
  local time = since(s, now)
  if s.folder == "" or s.folder == s.tag then return time end
  return s.folder .. " · " .. time
end

-- The card's lines; `tab` is the terminal tab's label, or nil.
function status.card(s, now, tab)
  local where = s.folder ~= "" and s.folder or "unknown folder"
  local lines = { tab and (where .. " · " .. tab) or where }

  local doing
  if s.mood == "permission" then
    doing = "waiting for permission: " .. (s.moodText or "a tool") .. " · " .. duration(now - s.seenAt)
  elseif s.mood == "asking" then
    doing = "waiting for your answer · " .. duration(now - s.seenAt)
  elseif isWorking(s) then
    doing = "working " .. duration(now - (s.turnAt or s.seenAt))
  else
    doing = "idle " .. duration(now - s.seenAt)
  end
  lines[2] = s.command and ("/" .. s.command .. " · " .. doing) or doing

  local live, done = agentCounts(s)
  if live + done > 0 then
    local parts = {}
    if live > 0 then parts[#parts + 1] = live .. " working" end
    if done > 0 then parts[#parts + 1] = done .. " done" end
    lines[#lines + 1] = "subagents: " .. table.concat(parts, ", ")
  end
  if (s.tools or 0) > 0 then
    local calls = s.tools == 1 and "1 tool call" or (s.tools .. " tool calls")
    lines[#lines + 1] = s.lastTool and (calls .. " · last: " .. s.lastTool) or calls
  end
  if not isWorking(s) and s.summary ~= "" then
    lines[#lines + 1] = "last reply: " .. shorten(s.summary, REPLY_CHARS)
  end
  return lines
end

return status
