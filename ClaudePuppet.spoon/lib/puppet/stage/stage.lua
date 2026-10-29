-- The puppets on screen: one floating canvas and one bubble per key, lined up leftwards from an anchor point.

local config = require("puppet.config")
local pixels = require("puppet.render.pixels")
local bubble = require("puppet.stage.bubble")

local Stage = {}
Stage.__index = Stage

local function floating(canvas)
  canvas:level(hs.canvas.windowLevels.floating)
  canvas:behavior({ "canJoinAllSpaces", "stationary" })
  canvas:clickActivating(false)
  canvas:canvasMouseEvents(true, false, false, false)
  return canvas
end

-- opts: pixel, anchor, onMouseDown(key), onBubbleClick(key).
function Stage.new(opts)
  return setmetatable({
    puppets = {}, keys = {}, pixel = opts.pixel, anchor = opts.anchor, isShown = true,
    onMouseDown = opts.onMouseDown, onBubbleClick = opts.onBubbleClick,
  }, Stage)
end

-- A new puppet and its bubble, in the first colour of `palette` no other puppet wears.
function Stage:add(key, palette)
  local used = {}
  for _, puppet in pairs(self.puppets) do used[puppet.color] = true end
  local color = palette[1]
  for _, hex in ipairs(palette) do
    if not used[hex] then
      color = hex
      break
    end
  end
  local px = self.pixel
  local canvas = floating(hs.canvas.new({ x = self.anchor.x, y = self.anchor.y, w = config.W * px, h = config.H * px }))
  canvas:mouseCallback(function(_, message)
    if message == "mouseDown" then self.onMouseDown(key) end
  end)
  local balloon = floating(hs.canvas.new({ x = self.anchor.x, y = self.anchor.y - 40, w = 200, h = bubble.HEIGHT }))
  balloon:mouseCallback(function(_, message)
    if message == "mouseDown" then self.onBubbleClick(key) end
  end)
  local puppet = { canvas = canvas, bubble = balloon, color = color, colors = pixels.colorsFor(color) }
  self.puppets[key] = puppet
  return puppet
end

function Stage:remove(key)
  local puppet = self.puppets[key]
  if puppet.bubbleTimer then puppet.bubbleTimer:stop() end
  puppet.canvas:delete()
  puppet.bubble:delete()
  self.puppets[key] = nil
end

-- Shows exactly `keys`, in order from the anchor leftwards; paletteOf(key) colours a new puppet.
function Stage:sync(keys, paletteOf)
  local wanted = {}
  for _, key in ipairs(keys) do wanted[key] = true end
  for key in pairs(self.puppets) do
    if not wanted[key] then self:remove(key) end
  end
  for i, key in ipairs(keys) do
    local puppet = self.puppets[key] or self:add(key, paletteOf(key))
    puppet.canvas:topLeft({ x = self.anchor.x - (i - 1) * (config.W * self.pixel + config.GAP), y = self.anchor.y })
    if self.isShown then puppet.canvas:show() end
    if puppet.bubble:isShowing() then
      local f = puppet.bubble:frame()
      puppet.bubble:frame(bubble.frame(puppet.canvas:topLeft(), self.pixel, f.w, f.h))
    end
  end
  self.keys = keys
end

-- Shows a bubble above a puppet until the next one, or for `seconds`; no text hides it.
function Stage:say(key, text, seconds)
  local puppet = self.puppets[key]
  if not puppet then return end
  if puppet.bubbleTimer then
    puppet.bubbleTimer:stop()
    puppet.bubbleTimer = nil
  end
  if not text or text == "" then
    puppet.bubble:hide()
    return
  end
  bubble.show(puppet, text, self.pixel)
  if self.isShown then puppet.bubble:show() end
  if seconds then puppet.bubbleTimer = hs.timer.doAfter(seconds, function() self:say(key, nil) end) end
end

function Stage:toggle()
  self.isShown = not self.isShown
  for _, puppet in pairs(self.puppets) do
    if self.isShown then
      puppet.canvas:show()
    else
      puppet.canvas:hide()
      puppet.bubble:hide()
    end
  end
end

function Stage:removeAll()
  for key in pairs(self.puppets) do self:remove(key) end
end

return Stage
