local gui = require("goonUi.lua")
local gog = require("goonLog.lua")
local gut = require("goonUtils.lua")
local rot = require("rotations_v3.lua")
local gnl = require("notificationsLinux.lua")

-- config ----------------------------------------------------------------------

-- don't modify this, these are options for atkMethod (below this)
local atkMethods = {
  none = "none", -- doesn't attack by any means, just keeps fishing
  oneshot = "oneshot", -- just uses the weapon once and goes back to fishing
  oneshotEvery = "oneshotEvery" -- same as oneshot, but every x times
}

-- method to use for killing mobs, use the list above to choose one
local atkMethod = atkMethods.oneshotEvery
-- value for oneshotEvery atkMethod, oneshots every x amounts you catch something
local oneshotEveryValue = 4

-- hunt mobs (define targets below)
local hunt = true
-- get the names from below's table named scs
local huntTargets = {
  "night_squid",
  "squid",
  "frog",
  -- "bogged",
  "ent",
  "skeleton"
}

-- snap fishing angle
local snapFish = true
-- weather to snap to a angle to attack then snap back for fishing
local snapAttack = true
-- what angle to snap (use nil if you want either one to be the same)
local snapAttackDirection = { yaw = 0, pitch = 0 }

local SLOTS = {
  ROD = 1,
  ATK = 3,
  HUNTAXE = 5,
  EW = 6
}

local lookDirection = { yaw = -180, pitch = -0 }
local alertWhenNotLookingAtDirection = false

-- position yourself in a specific spot
-- also the toggle for auto-buying rain
local togglePositioning = false

-- recast if nothing caught in x ticks value
local recastIfNothingCaughtInXTicks = 70

-- tick ranges (random cooldown before doing stuff)
local CATCH = {2, 3} -- for catching after detection
local ATTACK = {1, 2} -- for attacking after catching
local RECAST = {2, 3} -- for recasting after catching
local HIT_HUNT_CREATURE_TIMES = 3 -- times to hit a create for hunting

rot.setRotationSpeed(28)
rot.setModifier(10)

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
  double_hook = {
    name = "double_hook",
    str = "§eIt's a §aDouble Hook§e!",
    catches = 0
  },
  carrot_king = {
    name = "carrot_king",
    str = "§aIs this even a fish? It's the Carrot King!",
    catches = 0
  },
  agarimoo = {
    name = "agarimoo",
    str = "§aYour Chumcap Bucket trembles, it's an Agarimoo.",
    catches = 0
  },
  squid = {
    name = "squid",
    str = "§aA Squid appeared.",
    catches = 0
  },
  night_squid = {
    name = "night_squid",
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
  hunting = "hunting"
}
local state = states.idle
local lastState
local tick = 0
local time = 0
-- local chatTime = -1
-- local huntaxeAble = false
local huntTarget = nil
local huntTargetsHitList = {}
local snapFishRotation = nil
local caughtFastest = 99
local caughtSlowest = 0
local caughtInSigma = 0
local caught = 0
local caughtLastUUID = nil
local wait = 0
local waitRotationAlert = 20
local location = "idk"
local nearbyEntities = nil
local raycast = nil
local isLookingAtHuntTarget = false
gog.config.logTypes.info.enabled = true
gog.config.logTypes.debug.enabled = true
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
  or state == states.hunting
  then
    time = time + 1
  end
end

-- local function chatTimeProceed()
--   if chatTime == -1 then return end
--   chatTime = chatTime + 1
-- end

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
-- local function resetChatTime()
--   chatTime = -1
-- end

local function getHuntTarget()

  -- early exit if no creatures nearby or nil
  if not nearbyEntities
  or #nearbyEntities == 0
  then
    huntTarget = nil
    return
  end

  local detectedEntity = nil
  for _, entity in ipairs(nearbyEntities) do
    if not entity.name then goto bruh end
    local name = string.lower(entity.name)

    -- entity is to be hunted
    if not gut.isTargetInTableOfStrings(name, huntTargets)
    then goto bruh end
    -- entity is not an armor stand
    if entity.type == "entity.minecraft.armor_stand"
    then goto bruh end
    -- entity is not blacklisted or not hit for required amount
    if huntTargetsHitList[entity.uuid]
    and (
      huntTargetsHitList[entity.uuid] == 999 -- blacklist number
      or huntTargetsHitList[entity.uuid] > (HIT_HUNT_CREATURE_TIMES -1)
    )
    then goto bruh end

    detectedEntity = entity
    break

    ::bruh::
  end
  if detectedEntity then huntTarget = detectedEntity return end
  huntTarget = nil
end

local function getLookingAtHuntTarget()

  -- early exits
  if not raycast
  or not huntTarget
  then
    isLookingAtHuntTarget = false
    return
  end

  if raycast.type ~= "entity" then
    isLookingAtHuntTarget = false
    return
  end
  -- is looking at entity
  if raycast.data.uuid == huntTarget.uuid then
    isLookingAtHuntTarget = true
  else isLookingAtHuntTarget = false end
end

local function stateSwitch(new_state)
  lastState = state
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
    wait = math.random(3, 6)
  elseif new_state == states.buyingRain then
    wait = math.random(2, 4)
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
  or (
    curSlot ~= SLOTS.ROD
    and curSlot ~= SLOTS.ATK
    and curSlot ~= SLOTS.EW
    and curSlot ~= SLOTS.HUNTAXE
  )
  or (location ~= "foraging_1" and location ~= "foraging_2")
  then
    tick = 0
    if state ~= states.idle then stateSwitch(states.idle) end
    return
  end

  -- consistent stuff
  tickProceed()
  timeProceed()
  -- chatTimeProceed()
  waitRotationAlertProceed()
  getHuntTarget()
  getLookingAtHuntTarget()
  nearbyEntities = gut.getNearbyEntities(3, 3)
  raycast = player.raycast(3)
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
    -- resetChatTime()

    if rod == nil then return end
    stateSwitch(states.fishing)

    if not snapFish then return end
    snapFishRotation = player.getRotation()

  -- tpingToFishing ------------------------------------------------------------
  elseif state == states.tpingToFishing then

    if tick < wait then return end
    resetWait()

    -- carrot king pushing you prevention
    if nearbyEntities then
      for _, mob in ipairs(nearbyEntities) do
        if mob.type == "entity.minecraft.rabbit" then
          gog.critical("going idle, detected carrot king")
          gnl.snowNotify("skyblock", "carrot king")
          -- changing slot cuz if rod is out and king is present
          -- notifications will be spammed
          player.input.setSelectedSlot(8)
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

    player.input.rightClick()
    gog.debug("etherwarped to fishing pos")
    player.input.setPressedSneak(false)
    wait = 20
    resetTick()

  -- fishing -------------------------------------------------------------------
  elseif state == states.fishing then

    if tick < wait then return end
    resetWait()

    -- recasting cuz rod not out for 3.5s, while fishing
    if rod == nil
    and tick > 70
    then
      gog.info("recasting cuz rod not out for 3.5s, while fishing")
      if hunt and huntTarget then stateSwitch(states.hunting) return end
      stateSwitch(states.recasting)
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
      if hunt and huntTarget then stateSwitch(states.hunting) return end
      player.input.rightClick()
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
    player.input.rightClick()
    gog.debug("caught")
    -- chatTime = 0

    -- decide next state weather to atk or not
    local new_state = states.recasting

    if atkMethod == atkMethods.oneshot then
      new_state = states.attacking

    elseif hunt and huntTarget then
      new_state = states.hunting

    elseif atkMethod == atkMethods.oneshotEvery
    and caught % oneshotEveryValue == 0
    then new_state = states.attacking

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
    player.input.rightClick()
    gog.debug("attacked")
    if hunt and huntTarget
    then
      stateSwitch(states.hunting)
      wait = 10
      return
    end
    stateSwitch(states.recasting)

  -- hunting -------------------------------------------------------------------

  elseif state == states.hunting then

    if tick < wait then return end
    resetWait()

    -- early exit
    if not huntTarget then
      stateSwitch(states.recasting)
      return
    end

    -- make an entry in the set
    if not huntTargetsHitList[huntTarget.uuid] then
      huntTargetsHitList[huntTarget.uuid] = 0
    -- proceed only if target hit less than 2 times
    elseif huntTargetsHitList[huntTarget.uuid] > (HIT_HUNT_CREATURE_TIMES - 1) then
      stateSwitch(states.recasting)
      return
    end

    -- equip axe, only if stateLast was catching
    if curSlot
    and curSlot ~= SLOTS.HUNTAXE
    and (
      lastState == states.catching
      or lastState == states.fishing
    )
    then
      lastState = states.hunting -- ensure it only equips once
      player.input.setSelectedSlot(SLOTS.HUNTAXE)
      gog.debug("selected huntaxe slot")
      wait = 2 -- delay after equipping huntaxe
      resetTick()
      return
    end

    -- look at target
    -- NOTE: change isLookingAtHuntTarget to just its staring at it
    if not isLookingAtHuntTarget then
      local c = huntTarget.box.getCenter()
      rot.rotateToCoordinates(c.x, c.y, c.z)

      -- exit and blacklist cuz it took too long
      if tick > 60 then
        -- huntTargetsHitList[huntTarget.uuid] = 999
        stateSwitch(states.attacking)
      end
      return
    end

    -- TODO: remove times-hit and just hit till the mob is gone or off-reach
    -- thats also removes the need for loch check btw
    player.input.leftClick()
    if string.lower(huntTarget.name) ~= "skeleton" then
      huntTargetsHitList[huntTarget.uuid] = huntTargetsHitList[huntTarget.uuid] + 1
    end
    gog.debug("hunt target hit, uuid: " .. tostring(huntTarget.uuid))
    wait = math.random(10, 11)
    resetTick()

  -- recasting -----------------------------------------------------------------
  elseif state == states.recasting then

    if tick < wait then return end
    resetWait()

    -- re-equip rod, only if stateLast was attacking
    if curSlot
    and curSlot ~= SLOTS.ROD
    and (
      lastState == states.attacking
      or lastState == states.tpingToFishing
      or lastState == states.hunting
    )
    then
      lastState = states.recasting -- ensure only equips once
      player.input.setSelectedSlot(SLOTS.ROD)
      gog.debug("selected rod slot")
      wait = 2 -- delay after equipping rod
      resetTick()
      return
    end

    -- snapFish
    if snapFish
    and snapFishRotation
    and (
      snapFishRotation.yaw ~= curRot.yaw
      or snapFishRotation.pitch ~= curRot.pitch
    )
    and (
      lastState == states.recasting
      or lastState == states.hunting
    )
    then
      rot.rotateToYawPitch(snapFishRotation.yaw, snapFishRotation.pitch)
      return
    end

    player.input.rightClick()
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

    player.input.rightClick()
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
    if key == "double_hook" then goto alright end
    scsCaught = scsCaught + data.catches
    ::alright::
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
  -- table.insert(content, { text = "chatTime: " .. chatTime })
  -- table.insert(content, { text = "huntaxeAble: " .. tostring(huntaxeAble) })
  table.insert(content, { text = "nearbyEntities: " .. (nearbyEntities and #nearbyEntities or "idk") })
  -- table.insert(content, { text = "spanFishRot: " .. (snapFishRotation and gut.tableToString(snapFishRotation) or "idk") })
  -- table.insert(content, { text = "huntTargetsHitList: " .. (huntTargetsHitList and gut.tableToString(huntTargetsHitList) or "idk") })
  table.insert(content, { text = "huntTarget: " ..
    (huntTarget and tostring(huntTarget.display_name) or "nil") .. " " ..
    -- (huntTarget and tostring(huntTarget.health) or "hp") .. " " ..
    -- (huntTarget and tostring(huntTarget.max_health) or "mhp") .. " " ..
    (huntTarget and tostring(huntTarget.type) or "type")
  })
  table.insert(content, { text = "isLookingAtHuntTarget: " .. tostring(isLookingAtHuntTarget) })
  table.insert(content, { text = "raycast: " .. (
    raycast
    and raycast.type == "entity"
    and tostring(raycast.data.display_name)
    or "nil"
  )})

  gui.content = content

end)

registerMessageEvent(function(text, overlay, json)

  if overlay then return end
  if json then return end
  if not text then return end

  local txt = string.lower(text)
  -- if string.find(txt, "double") then
  --   print(">>>>>> " .. text)
  -- end

  if txt:find(player.getName(), 1, true) then
    gnl.snowNotify("skyblock", gut.remMcColors(text))
  end

  -- this is for hunting with chat messages isntead of detecting nearby mobs
  -- aka huntaxeCreature
  -- for _, creature in pairs(scs) do
  --   if string.find(text, creature.str) then
  --     creature.catches = creature.catches + 1
  --     gog.debug("chat msg in " .. tostring(chatTime))
  --     if huntaxe and huntaxeThese[creature.name] then
  --       huntaxeAble = true
  --     end
  --     break
  --   end
  -- end

end)

registerWorldRenderer(function (context)

  if not huntTarget then return end

  local line = {
    box = huntTarget.box,
    red = 255, green = 0, blue = 0, alpha = 255,
    line_width = 2
  }
  -- context.renderLineFromCursor(line)
  context.renderOutline(line)

end)

return "marina feet"
