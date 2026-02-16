local gui = require("goonUi.lua")
local gog = require("goonLog.lua")
local gut = require("goonUtils.lua")
local rot = require("rotations_v2.lua")

-- config ----------------------------------------------------------------------

-- don't modify this
local atkMethods = {
  none = "none", -- doesn't attack by any means, just keeps fishing
  oneshot = "oneshot", -- just uses the weapon once and goes back to fishing
  oneshotEvery = "oneshotEvery" -- same as oneshot, but every x times
}

-- method to use for killing mobs, use the list above to choose one
local atkMethod = atkMethods.oneshot
-- value for oneshotEvery atkMethod, oneshots every x amounts you catch something
local oneshotEveryValue = 2

local SLOTS = {
  ROD = 0,
  ATK = 3,
  EW = 6
}

-- tick ranges (random cooldown before doing stuff)
local CATCH = {2, 4} -- for catching after detection
local ATTACK = {1, 2} -- for attacking after catching
local RECAST = {2, 5} -- for recasting after catching

--- config end -----------------------------------------------------------------

local ew = {
  fishing = {
    block = { -304.5, 72.5, -55.5 },
    pos = { x = -304.5, y = 73, z = -55.5 }
  },
  rain = {
    block = { -304.5, 75.5, -76.5 },
    pos = { x = -304.5, y = 76, z = -76.5 }
  }
}
local states = {
  idle = "idle",
  tpingToFishing = "tpingToFishing",
  fishing = "fishing",
  catching = "catching",
  attacking = "attacking",
  recasting = "recasting",
  tpingToRain = "tpingToRain",
  buyingRain = "buyingRain"
}
local state = states.idle
local tick = 0
local wait = 0
local caught = 0
gog.config.logTypes.info.enabled = true
gui.config.gapInLinesFromTop = 1
gut.tgl.rain = true

--- helper functions -----------------------------------------------------------

local function tickProceed()
  tick = tick + 1
end

local function resetWait()
  wait = 0
end
local function resetTick()
  tick = 0
end

local function stateSwitch(new_state)
  state = new_state
  tick = 0
  if new_state == states.tpingToFishing then
    wait = math.random(5, 9)
  elseif new_state == states.fishing then
    wait = math.random(5, 8)
  elseif new_state == states.catching then
    wait = math.random(CATCH[1], CATCH[2])
  elseif new_state == states.attacking then
    wait = math.random(ATTACK[1], ATTACK[2])
  elseif new_state == states.recasting then
    wait = math.random(RECAST[1], RECAST[2])
  elseif new_state == states.tpingToRain then
    wait = math.random(5, 9)
  elseif new_state == states.buyingRain then
    wait = math.random(5, 9)
  end
end

--- registers ------------------------------------------------------------------

registerClientTickPre(function()

  -- consistent stuff but before early exists
  local location = player.getRawLocation()
  local curSlot = player.input.getSelectedSlot()
  local anyScreenOpened = player.inventory.isAnyScreenOpened()
  local title = player.inventory.getChestTitle()

  -- early exits
  if (anyScreenOpened and title ~= "Vanessa")
  or (curSlot ~= SLOTS.ROD and curSlot ~= SLOTS.ATK and curSlot ~= SLOTS.EW)
  or location ~= "foraging_1"
  then
    tick = 0
    stateSwitch(states.idle)
    return
  end

  -- consistent stuff
  tickProceed()
  local rod = player.fishHook
  local pos = player.getPos()
  local curRot = player.getRotation()
  local sneaking = player.input.isPressedSneak()
  if state ~= states.idle then rot.update() end

  -- states

  -- idle ----------------------------------------------------------------------
  if state == states.idle then

    if tick < wait then return end
    resetWait()
    resetTick()
    if rod ~= nil then stateSwitch(states.fishing) end

  -- tpingToFishing ------------------------------------------------------------
  elseif state == states.tpingToFishing then

    if tick < wait then return end
    resetWait()

    -- position
    if pos.x == ew.fishing.pos.x
    and pos.y == ew.fishing.pos.y
    and pos.z == ew.fishing.pos.z
    then
      stateSwitch(states.recasting)
      return
    end

    -- swap to etherwarp
    if curSlot ~= SLOTS.EW then
      player.input.setSelectedSlot(SLOTS.EW)
      wait = 5
      resetTick()
      return
    end

    -- sneak
    if not sneaking then
      player.input.setPressedSneak(true)
      wait = 5
      resetTick()
      return
    end

    -- world.getRotation is buggy when yaw is 0, it just doesn't return the expected values, instead returns the current yaw/pitch ? tf idk
    if curRot.yaw == 0 then
      rot.rotateToYawPitch(curRot.yaw + 0.1, curRot.pitch)
      return
    end

    local worldRot = world.getRotation(ew.fishing.block[1], ew.fishing.block[2], ew.fishing.block[3])
    if curRot.yaw ~= worldRot.yaw
    and curRot.pitch ~= worldRot.pitch
    then
      rot.rotateToYawPitch(worldRot.yaw, worldRot.pitch)
      return
    end

    player.input.silentUse(SLOTS.EW)
    gog.info("etherwarped to fishing pos")
    player.input.setPressedSneak(false)
    wait = 20
    resetTick()

  -- fishing -------------------------------------------------------------------
  elseif state == states.fishing then

    if tick < wait then return end
    resetWait()

    -- idle
    if rod == nil
    and tick > 40
    then
      stateSwitch(states.idle)
    end

    -- position
    if pos.x ~= ew.fishing.pos.x
    or pos.y ~= ew.fishing.pos.y
    or pos.z ~= ew.fishing.pos.z
    then
      stateSwitch(states.tpingToFishing)
      return
    end

    -- low rain detection
    if gut.inf.rain < 10 then
      stateSwitch(states.tpingToRain)
      return
    end

    -- scan for bite
    local entities = world.getEntities()
    for _, entity in ipairs(entities) do
      local name = entity.name
      if name
      and (string.find(name, "!!!")
      or string.find(name, "ǃǃǃ")
      or string.find(name, "ꜝꜝꜝ"))
      then
        stateSwitch(states.catching)
        break
      end
    end

  -- catching ------------------------------------------------------------------
  elseif state == states.catching then

    if tick < wait then return end
    resetWait()
    caught = caught + 1
    player.input.silentUse(SLOTS.ROD)
    gog.info("caught")

    -- decide next state weather to atk or not
    local new_state = states.recasting
    if atkMethod == atkMethods.oneshot then
      new_state = states.attacking
    elseif atkMethod == atkMethods.oneshotEvery
    and caught % oneshotEveryValue == 0
    then
      new_state = states.attacking
    end
    stateSwitch(new_state)

  -- attacking -----------------------------------------------------------------
  elseif state == states.attacking then

    if tick < wait then return end
    resetWait()

    -- equip weapon
    if curSlot and curSlot ~= SLOTS.ATK then
      player.input.setSelectedSlot(SLOTS.ATK)
      gog.info("selected atk slot")
      wait = 2 -- delay after equipping weapon
      resetTick()
      return
    end

    -- attack
    player.input.silentUse(SLOTS.ATK)
    gog.info("attacked")
    stateSwitch(states.recasting)

  -- recasting -----------------------------------------------------------------
  elseif state == states.recasting then

    if tick < wait then return end
    resetWait()

    -- re-equip rod
    if curSlot and curSlot ~= SLOTS.ROD then
      player.input.setSelectedSlot(SLOTS.ROD)
      gog.info("selected rod slot")
      wait = 2 -- delay after equipping rod
      resetTick()
      return
    end

    -- look down
    if curRot.pitch ~= 90
    then
      rot.rotateToYawPitch(curRot.yaw, 90)
      return
    end

    player.input.silentUse(SLOTS.ROD)
    gog.info("recasted")
    stateSwitch(states.fishing)

  -- tpingToRain ---------------------------------------------------------------
  elseif state == states.tpingToRain then

    if tick < wait then return end
    resetWait()

    -- position
    if pos.x == ew.rain.pos.x
    and pos.y == ew.rain.pos.y
    and pos.z == ew.rain.pos.z
    then
      stateSwitch(states.buyingRain)
      return
    end

    -- swap to etherwarp
    if curSlot ~= SLOTS.EW then
      player.input.setSelectedSlot(SLOTS.EW)
      wait = 5
      resetTick()
      return
    end

    -- sneak
    if not sneaking then
      player.input.setPressedSneak(true)
      wait = 5
      resetTick()
      return
    end

    -- world.getRotation is buggy when yaw is 0, it just doesn't return the expected values, instead returns the current yaw/pitch ? tf idk
    -- if curRot.yaw == 0 then
    --   rot.rotateToYawPitch(curRot.yaw + 0.1, curRot.pitch)
    --   return
    -- end

    local worldRot = world.getRotation(ew.rain.block[1], ew.rain.block[2], ew.rain.block[3])
    if curRot.yaw ~= worldRot.yaw
    and curRot.pitch ~= worldRot.pitch
    then
      rot.rotateToYawPitch(worldRot.yaw, worldRot.pitch)
      return
    end

    player.input.silentUse(SLOTS.EW)
    gog.info("etherwarped to rain pos")
    player.input.setPressedSneak(false)
    wait = 20
    resetTick()

  elseif state == states.buyingRain then

    if tick < wait then return end
    resetWait()

    -- stop when 28m of rain bought (rain number never goes above 1740)
    if gut.inf.rain > 1680 then
      player.inventory.closeScreen()
      stateSwitch(states.tpingToFishing)
    end

    -- position
    if pos.x ~= ew.rain.pos.x
    and pos.y ~= ew.rain.pos.y
    and pos.z ~= ew.rain.pos.z
    then
      stateSwitch(states.tpingToRain)
      return
    end

    if not anyScreenOpened then
      player.input.leftClick()
      player.addMessage("left clicked rain npc")
      wait = 40
      resetTick()
    end

    player.inventory.leftClick(13)
    wait = math.random(4, 7)
    resetTick()

  end

end)

register2DRenderer(function(context)

  local pos = player.getPos()

  gui.content = {
    { text = "state: " .. state },
    { text = "tick: " .. tick },
    { text = "wait: " .. wait },
    { text = "caught: " .. caught },
    { text = "rot: " .. tostring(rot.isRotating()) },
    { text = "rain: " .. gut.inf.rain }
  }

end)

return "marina feet"
