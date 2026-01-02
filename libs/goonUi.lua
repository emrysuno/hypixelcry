local all = {}
all.config = {
  baseXOffset = 4,
  baseYOffset = 4,
  lineSpacing = 12,     -- Vertical distance between lines
  defaultRGB = { 255, 255, 255 }
}
all.content = {
  { text = "hello with gap below", rgb = { 255, 0, 0 }, extraSpace = 4 },
  { text = "hello in red", rgb = {255, 0, 0} },
  { text = "hello in green", rgb = {0, 255, 0} },
  { text = "hello in blue", rgb = {0, 0, 255} },
}

local function infoUi(context)

  local data = all.content
  local currentY = all.config.baseYOffset

  for _, line in ipairs(data) do

    local color = line.rgb or all.config.defaultRGB

    context.renderText({
      x = all.config.baseXOffset,
      y = currentY,
      scale = 1,
      text = line.text,
      red = color[1],
      green = color[2],
      blue = color[3]
    })

    currentY = currentY + all.config.lineSpacing + (line.extraSpace or 0)

  end

end

register2DRenderer(function(context)

  infoUi(context)

end)

return all
