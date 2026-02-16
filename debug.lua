local gut = require("goonUtils.lua")
local gui = require("goonUi.lua")

-- lib config ------------------------------------------------------------------

gui.config.gapInLinesFromTop = 1
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
  "squid",
  "zombie",
  "skeleton",
  "silverfish",
  "guardian",
  "witch",
  "rabbit",
  "iron_golem",
  "ocelot",
  "chicken",
  "slime",
  "cow",
  "mooshroom"
})

local p = "idk"

-- registerSpawnParticle(function(data)
--   local id = data.id -- number
--   p = tostring(id)
--
--   local x = data.x -- number
--   local y = data.y -- number
--   local z = data.z -- number
--
--   local x_dist = data.x_dist -- number
--   local y_dist = data.y_dist -- number
--   local z_dist = data.z_dist -- number
--
--   local max_speed = data.max_speed-- number
--   local count = data.count-- number
--
-- end)

register2DRenderer(function(ctx)

  local mobs = gut.getNearbyEntities(5, 5)
  local mobDisplay = #mobs
  for _, mob in ipairs(mobs) do
    mobDisplay = mobDisplay .. ", " .. mob.type .. " " .. mob.name .. " " .. mob.display_name
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
    { text = p },
    -- { text = "pos: " .. gut.tableToString(gut.inf.pos) },
    -- { text = "vel: " .. gut.inf.velocity },
    -- { text = "location: " .. gut.inf.location },
    -- { text = "blockBelowFeet: " .. gut.inf.blockBelowFeet },
    -- { text = "rain: " .. gut.inf.rain },
    -- { text = "title: " .. tostring(player.inventory.getChestTitle()) }
  }

end)

