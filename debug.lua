local gut = require("goonUtils.lua")
local gui = require("goonUi.lua")
local rot = require("rotations_v2.lua")

-- lib config ------------------------------------------------------------------

gui.config.baseOffset = {150, 4}
-- gui.config.gapInLinesFromTop = 16
gut.tgl.pet = true
gut.tgl.pos = true
gut.tgl.velocity = true
gut.tgl.location = true
gut.tgl.blockBelowFeet = true
gut.tgl.rain = true

-- temp
local ignoreEntitiesByType = gut.addPrefixToATableOfStrings("entity.minecraft.", {
  "experience_orb",
  "fishing_bobber",
  "item",
  "falling_block",
  "bat",
  "armor_stand",
  -- "squid",
  "zombie",
  "skeleton",
  "silverfish",
  "guardian",
  "witch",
  -- "rabbit",
  -- "iron_golem",
  "ocelot",
  "chicken",
  "slime",
  "cow",
  "mooshroom"
})

local idkp = { x=-1, y=-1, z=-1 }
local p = idkp

register2DRenderer(function(ctx)

  local mobs = gut.getNearbyEntities(5, 5)
  local mobDisplay = #mobs
  for _, mob in ipairs(mobs) do
    mobDisplay = mobDisplay .. ", " .. mob.name
  end
  mobDisplay = mobDisplay

  gui.content = {
    { text = (
      gut.getColoredStatusInStringOfAFunction("L", player.input.isPressedAttack()) .. " " ..
      gut.getColoredStatusInStringOfAFunction("W", player.input.isPressedForward()) .. " " ..
      gut.getColoredStatusInStringOfAFunction("R", player.input.isPressedUse()) .. " " ..
      gut.getColoredStatusInStringOfAFunction("S", player.isSprinting())
    )},
    { text = (
      gut.getColoredStatusInStringOfAFunction("A", player.input.isPressedLeft()) .. " " ..
      gut.getColoredStatusInStringOfAFunction("S", player.input.isPressedBack()) .. " " ..
      gut.getColoredStatusInStringOfAFunction("D", player.input.isPressedRight()) .. " " ..
      gut.getColoredStatusInStringOfAFunction("C", player.isSneaking())
    )},
    { text = gut.getColoredStatusInStringOfAFunction("rod", player.fishHook, false) },

    -- { text = "pet: " .. gut.inf.pet .. gut.clr.white .. " > " .. gut.inf.petName },
    { text = "entities nearby: " .. mobDisplay },
    -- { text = "p: " .. gut.tableToString(p) },
    -- { text = "pos: " .. gut.tableToString(gut.inf.pos) },
    -- { text = "vel: " .. gut.inf.velocity },
    -- { text = "location: " .. gut.inf.location },
    -- { text = "blockBelowFeet: " .. gut.inf.blockBelowFeet },
    -- { text = "rain: " .. gut.inf.rain },
    -- { text = "title: " .. tostring(player.inventory.getChestTitle()) }
  }

end)

local tick = 0
local pc = nil

registerClientTickPre(function()

  rot.update()
  tick = tick + 1
  local nearbyEntities = gut.getNearbyEntities(5, 5)
  p = idkp

  for _, mob in ipairs(nearbyEntities) do
    local mobName = mob.name and string.lower(mob.name) or ""
    if string.find(mobName, "nyasuh") then
      p = mob
      break
    end
  end

  if p == idkp then return end
  -- rot.rotateToCoordinates(p.x, p.y, p.z)
  pc = p.box

end)

registerWorldRenderer(function (context)

  if not pc then return end

  local line = {
    box = pc,
    red = 102, green = 255, blue = 153, alpha = 140,
    line_width = 2
  }
  -- context.renderLineFromCursor(line)
  context.renderOutline(line)

end)
