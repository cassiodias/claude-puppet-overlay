-- A puppet's speech bubble: no wider than the puppet, so neighbours' bubbles never overlap; long text wraps
-- onto a few lines. It sits above the puppet, right edges lined up, inside the screen the puppet is on
-- (below the puppet when there is no room above).

local config = require("puppet.config")

local HEIGHT, GAP, SCREEN_MARGIN, MAX_LINES = 34, 6, 8, 4

local bubble = { HEIGHT = HEIGHT }

function bubble.frame(top, pixel, width, height)
  local puppetWidth, puppetHeight = config.W * pixel, config.H * pixel
  local center = { x = top.x + puppetWidth / 2, y = top.y + puppetHeight / 2 }
  local screen = hs.screen.mainScreen():frame()
  for _, each in ipairs(hs.screen.allScreens()) do
    local f = each:frame()
    if center.x >= f.x and center.x < f.x + f.w and center.y >= f.y and center.y < f.y + f.h then screen = f end
  end
  local x = top.x + puppetWidth - width
  x = math.max(screen.x + SCREEN_MARGIN, math.min(x, screen.x + screen.w - width - SCREEN_MARGIN))
  local y = top.y - height - GAP
  if y < screen.y + SCREEN_MARGIN then y = top.y + puppetHeight + GAP end
  return { x = x, y = y, w = width, h = height }
end

-- Draws `text` into a puppet's bubble canvas, sized and placed for it.
function bubble.show(puppet, text, pixel)
  local textWidth = 7 * (utf8.len(text) or #text)
  local width = math.min(config.W * pixel, textWidth + 24)
  local lines = math.min(MAX_LINES, math.ceil(textWidth / (width - 24)))
  local height = HEIGHT + (lines - 1) * 15
  puppet.bubble:frame(bubble.frame(puppet.canvas:topLeft(), pixel, width, height))
  puppet.bubble:replaceElements({
    { type = "rectangle", action = "strokeAndFill", fillColor = { white = 1, alpha = 0.95 },
      strokeColor = { hex = puppet.color }, strokeWidth = 2, roundedRectRadii = { xRadius = 10, yRadius = 10 } },
    { type = "text", text = text, textColor = { white = 0.1 }, textSize = 12,
      textLineBreak = "wordWrap", frame = { x = 12, y = 8, w = width - 24, h = height - 14 } },
  })
end

return bubble
