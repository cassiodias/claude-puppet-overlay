-- The home puppet waits when no session has a puppet, and dozes off after a while.

local config = require("puppet.config")
local pixels = require("puppet.render.pixels")
local sprites = require("puppet.render.sprites")
local label = require("puppet.render.text").label
local fill, stamp = pixels.fill, pixels.stamp

return {
  draw = function(buf, texts, _, ctx)
    local W, H = config.W, config.H
    fill(buf, 0, 19, W - 1, 20, "b")
    fill(buf, 2, 21, 3, H - 1, "b")
    fill(buf, W - 4, 21, W - 3, H - 1, "b")
    local isAsleep = ctx.now - ctx.lastEventAt > config.IDLE_SLEEP_SECONDS
    stamp(buf, isAsleep and sprites.FRONT_ASLEEP or sprites.FRONT, 19, 14)
    if isAsleep then
      local rise = (ctx.frame // 5) % 4
      texts[#texts + 1] = label("z", 29 + rise, 11 - rise, 4, "left", ctx.pixel)
    end
  end,
}
