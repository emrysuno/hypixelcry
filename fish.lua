local gui = require("goonUi.lua")
local gog = require("goonLog.lua")
local gut = require("goonUtils.lua")
local rot = require("rotations_v2.lua")
local gnl = require("notificationsLinux.lua")

-- config ----------------------------------------------------------------------

-- don't modify this, these are options for atkMethod (below this)
local atkMethods = {
  none = "none", -- doesn't attack by any means, just keeps fishing
  oneshot = "oneshot", -- just uses the weapon once and goes back to fishing
  oneshotEvery = "oneshotEvery" -- same as oneshot, but every x times
}

-- method to use for killing mobs, use the list above to choose one
local atkMethod = atkMethods.none
-- value for oneshotEvery atkMethod, oneshots every x amounts you catch something
local oneshotEveryValue = 2

local SLOTS = {
  ROD = 0,
  ATK = 3,
  EW = 6
}

local lookDirection = { yaw = -180, pitch = -0 }
local alertWhenNotLookingAtDirection = true

-- position yourself in a specific spot
-- also the toggle for auto-buying rain
local togglePositioning = true

-- recast if nothing caught in x ticks value
local recastIfNothingCaughtInXTicks = 80

-- tick ranges (random cooldown before doing stuff)
local CATCH = {2, 4} -- for catching after detection
local ATTACK = {1, 2} -- for attacking after catching
local RECAST = {2, 5} -- for recasting after catching

rot.setRotationSpeed(20)

gnl.defaultUrgency = "critical"
gnl.defaultTimeout = 0

--- config end -----------------------------------------------------------------

local ew = {
  fishing = {
    block = { -314.5, 72, -59.5 },
    pos = { x = -314.5, y = 72, z = -59.5 }
  },
  rain = {
    block = { -304.5, 75.5, -76.5 },
    pos = { x = -304.5, y = 76, z = -76.5 }
  }
}
local scs = {
  carrot_king = {
    str = "§aIs this even a fish? It's the Carrot King!",
    catches = 0
  },
  squid = {
    str = "§aA Squid appeared.",
    catches = 0
  },
  night_squid = {
    str = "§aPitch darkness reveals a Night Squid.",
    catches = 0
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
  buyingRain = "buyingRain",
}
local state = states.idle
local tick = 0
local time = 0
local caughtFastest = 99
local caughtSlowest = 0
local caughtInSigma = 0
local caught = 0
local caughtLastUUID = nil
local wait = 0
local waitRotationAlert = 20
local location = "idk"
gog.config.logTypes.info.enabled = true
gog.config.logTypes.debug.enabled = false
gog.config.logTypes.critical.enabled = true
gui.config.gapInLinesFromTop = 1
gut.tgl.rain = true

--- helper functions -----------------------------------------------------------

local function isRainLow()
  if togglePositioning
    and gut.inf.rain < 10
  then
    return true
  end
  return false
end

local function tickProceed()
  tick = tick + 1
end

local function timeProceed()
  if state == states.fishing
  or state == states.catching
  or state == states.recasting
  or state == states.attacking
  then
    time = time + 1
  end
end

local function waitRotationAlertProceed()
  if waitRotationAlert == 0 then return end
  if waitRotationAlert < 0 then waitRotationAlert = 0 return end
  waitRotationAlert = waitRotationAlert - 1
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
  if new_state == states.idle then
    gnl.snowNotify("skyblock", "going idle")
  elseif new_state == states.tpingToFishing then
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
  location = player.getRawLocation()
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
  timeProceed()
  waitRotationAlertProceed()
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

    -- carrot king pushing you prevention
    local nearbyEntities = gut.getNearbyEntities(2, 2)
    if nearbyEntities then
      for _, mob in ipairs(nearbyEntities) do
        if mob.type == "entity.minecraft.rabbit" then
          gog.critical("going idle, detected carrot king")
          gnl.snowNotify("skyblock", "carrot king")
          stateSwitch(states.idle)
          return
        end
      end
    end

    -- position
    if pos.x == ew.fishing.pos.x
    and pos.y == ew.fishing.pos.y
    and pos.z == ew.fishing.pos.z
    then

      -- look in fishing direction
      if curRot.pitch ~= lookDirection.pitch
      and curRot.yaw ~= lookDirection.yaw
      then
        rot.rotateToYawPitch(lookDirection.yaw, lookDirection.pitch)
        return
      end

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
    -- if curRot.yaw == 0 then
    --   rot.rotateToYawPitch(curRot.yaw + 0.1, curRot.pitch)
    --   return
    -- end

    local worldRot = world.getRotation(ew.fishing.block[1], ew.fishing.block[2], ew.fishing.block[3])
    if curRot.yaw ~= worldRot.yaw
    and curRot.pitch ~= worldRot.pitch
    then
      rot.rotateToYawPitch(worldRot.yaw, worldRot.pitch)
      return
    end

    player.input.silentUse(SLOTS.EW)
    gog.debug("etherwarped to fishing pos")
    player.input.setPressedSneak(false)
    wait = 20
    resetTick()

  -- fishing -------------------------------------------------------------------
  elseif state == states.fishing then

    if tick < wait then return end
    resetWait()

    -- going idle cuz rod not out for 3.5s, while fishing
    if rod == nil
    and tick > 70
    then
      gog.info("going idle cuz rod not out for 3.5s, while fishing")
      stateSwitch(states.idle)
    end

    -- alert about direction
    if alertWhenNotLookingAtDirection
    and curRot.yaw ~= lookDirection.yaw
    and curRot.pitch ~= lookDirection.pitch
    and waitRotationAlert == 0
    then
      gog.critical("rotation alert")
      gnl.snowNotify("skyblock", "rotation alert")
      waitRotationAlert = 40
    end

    -- position
    if togglePositioning
    and (pos.x ~= ew.fishing.pos.x
    or pos.y ~= ew.fishing.pos.y
    or pos.z ~= ew.fishing.pos.z)
    then
      stateSwitch(states.tpingToFishing)
      return
    end

    -- low rain detection
    if isRainLow() then
      stateSwitch(states.tpingToRain)
      return
    end

    -- recast if taking too long
    if tick > recastIfNothingCaughtInXTicks then
      gog.debug("recasting cuz nothing caught for a while")
      player.input.silentUse(SLOTS.ROD)
      stateSwitch(states.recasting)
      return
    end

    -- scan for bite
    local entities = world.getEntities()
    for _, entity in ipairs(entities) do
      local name = entity.name
      local uuid = entity.uuid
      if name
      and (string.find(name, "!!!")
      or string.find(name, "ǃǃǃ")
      or string.find(name, "ꜝꜝꜝ"))
      and uuid ~= caughtLastUUID
      then
        caughtLastUUID = uuid
        gog.debug("detected in " .. tostring(tick))
        caughtInSigma = caughtInSigma + tick
        if tick < caughtFastest then caughtFastest = tick end
        if tick > caughtSlowest then caughtSlowest = tick end
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
    gog.debug("caught")

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
      gog.debug("selected atk slot")
      wait = 2 -- delay after equipping weapon
      resetTick()
      return
    end

    -- attack
    player.input.silentUse(SLOTS.ATK)
    gog.debug("attacked")
    stateSwitch(states.recasting)

  -- recasting -----------------------------------------------------------------
  elseif state == states.recasting then

    if tick < wait then return end
    resetWait()

    -- re-equip rod
    if curSlot and curSlot ~= SLOTS.ROD then
      player.input.setSelectedSlot(SLOTS.ROD)
      gog.debug("selected rod slot")
      wait = 2 -- delay after equipping rod
      resetTick()
      return
    end

    player.input.silentUse(SLOTS.ROD)
    gog.debug("recasted")
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
    gog.debug("etherwarped to rain pos")
    player.input.setPressedSneak(false)
    wait = 20
    resetTick()

  -- buyingRain ----------------------------------------------------------------
  elseif state == states.buyingRain then

    if tick < wait then return end
    resetWait()

    -- stop when 28m of rain bought (rain number never goes above 1740)
    if gut.inf.rain > 1680 then
      gog.debug("enough rain bought")
      if anyScreenOpened then
        player.inventory.closeScreen()
        wait = 11
        resetTick()
        return
      end
      stateSwitch(states.tpingToFishing)
      return
    end

    -- position
    if pos.x ~= ew.rain.pos.x
    and pos.y ~= ew.rain.pos.y
    and pos.z ~= ew.rain.pos.z
    then
      stateSwitch(states.tpingToRain)
      return
    end

    -- look at npc
    if curRot.yaw ~= -179.0 then
      rot.rotateToYawPitch(-179.0, 20)
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

local graySlash = gut.clr.gray .. "/"

register2DRenderer(function(context)

  -- local pos = player.getPos()

  local scsCaught = 0
  local content = {

    { text = "time: " .. gut.convertTicksToTimeFormat(time) },
    { text = "rain: " .. gut.inf.rain },
    {
      text =
        "caught: " ..
        caught .. graySlash .. gut.clr.yellow ..
        math.floor((caught / (time / 20)) * 3600)
    },
    { text = "caught times: " ..
      gut.clr.green .. tostring(caughtFastest) ..
      graySlash ..
      gut.clr.yellow .. tostring(gut.roundUpToTwoDecimals(caughtInSigma / caught)) ..
      graySlash ..
      gut.clr.red .. tostring(caughtSlowest) }

  }

  for key, data in pairs(scs) do
    table.insert(
      content, {
        text =
          key .. ": " ..
          tostring(data.catches) ..
          graySlash ..
          gut.clr.yellow ..
          tostring(gut.roundUpToTwoDecimals((data.catches / caught) * 100))
      }
    )
    scsCaught = scsCaught + data.catches
  end
  local uselessCatches = caught - scsCaught
  table.insert(content, {
    text = "useless: " ..
      uselessCatches ..
      graySlash ..
      gut.clr.yellow ..
      tostring(gut.roundUpToTwoDecimals((uselessCatches / caught) * 100))
  })

  table.insert(content, { text = "" })
  table.insert(content, { text = "[debug]" })
  table.insert(content, { text = "state: " .. state })
  table.insert(content, { text = "tick: " .. tick })
  table.insert(content, { text = "wait: " .. wait })
  table.insert(content, { text = "rotating: " .. tostring(rot.isRotating()) })
  table.insert(content, { text = "waitRotationAlert: " .. waitRotationAlert })
  table.insert(content, { text = "location: " .. location })

  gui.content = content

end)

registerMessageEvent(function(text, overlay, json)

  if overlay then return end
  if json then return end
  if not text then return end

  local txt = string.lower(text)
  -- print("                  =======>>>>>> " .. text)

  if txt:find(player.getName(), 1, true) then
    gnl.snowNotify("skyblock", gut.remMcColors(text))
  end

  if text == scs.carrot_king.str then
    scs.carrot_king.catches = scs.carrot_king.catches + 1

  elseif text == scs.squid.str then
    scs.squid.catches = scs.squid.catches + 1

  elseif text == scs.night_squid.str then
    scs.night_squid.catches = scs.night_squid.catches + 1

  end


end)

return "marina feet"
