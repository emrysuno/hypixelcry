local gut = require("goonUtils.lua")
local gui = require("goonUi.lua")

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

register2DRenderer(function(ctx)

  local mobs = gut.getNearbyEntities(5, 5, ignoreEntitiesByType)
  local mobDisplay = #mobs
  for _, mob in ipairs(mobs) do
    mobDisplay = mobDisplay .. ", " .. mob.type
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
    { text = gut.getColoredStatusInStringOfAFunction("rod", player.fishHook, true) },
    { text = "pet: " .. gut.inf.pet },
    { text = "entities nearby: " .. mobDisplay },
    { text = "pos: " .. gut.tableToString(gut.inf.pos) },
    { text = "vel: " .. gut.inf.velocity },
    { text = "location: " .. gut.inf.location },
    { text = "test: " .. tostring(gut.tmp.test) }
  }

end)
