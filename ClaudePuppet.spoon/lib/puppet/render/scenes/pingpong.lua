-- Two puppets rally over a table; each seat is one of the turn's first two subagents, scoring its tool calls.

local config = require("puppet.config")
local pixels = require("puppet.render.pixels")
local sprites = require("puppet.render.sprites")
local label = require("puppet.render.text").label
local fill, stamp = pixels.fill, pixels.stamp

return {
  draw = function(buf, texts, s, ctx)
    local frame, px, W, H = ctx.frame, ctx.pixel, config.W, config.H
    -- Stand-ins hold the seats a command's turn has no subagent for.
    local left = s.agents[s.order[1]] or { label = s.tag, hits = s.score, done = false }
    local right = s.agents[s.order[2]] or { label = ctx.harness.id, hits = 0, done = false }
    fill(buf, 10, 17, W - 11, 18, "t")
    fill(buf, 12, 19, 12, H - 1, "g")
    fill(buf, W - 13, 19, W - 13, H - 1, "g")
    fill(buf, W // 2, 14, W // 2, 16, "w")
    stamp(buf, sprites.FRONT, 0, 13, left.done and "d" or nil)
    stamp(buf, sprites.FRONT, W - 9, 13, right.done and "d" or nil)
    if not left.done then fill(buf, 9, 13, 9, 15, "w") end
    if not right.done then fill(buf, W - 10, 13, W - 10, 15, "w") end

    local span = W - 22
    local p = frame % (2 * span)
    local x = p < span and p or 2 * span - p
    local y = 15 - math.floor(7 * math.sin(math.pi * x / span) + 0.5)
    fill(buf, 11 + x, y, 11 + x, y, "w")

    texts[#texts + 1] = label(left.label .. " " .. left.hits .. (left.done and " ✓" or ""), 0, 2, 22, "left", px)
    texts[#texts + 1] = label(right.label .. " " .. right.hits .. (right.done and " ✓" or ""), W - 22, 2, 22,
      "right", px)
  end,
}
