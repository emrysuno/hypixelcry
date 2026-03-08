local rotations = require("rotations_v2.lua")
local notifications = require("notifications.lua")
local pest_fly = require("goonPestFly.lua")
local gui = require("goonUi.lua")
local gut = require("goonUtils.lua")
local gog = require("goonLog.lua")
local cv = require("CryVigilance/index")
local inventory_utils = require("inventory_utils.lua")

-- config ----------------------------------------------------------------------

gog.config.logTypes.debug.enabled = false

-- key to toggle the script (doesn't stop when its killing pests)
-- find them in this channel https://discord.com/channels/1418100297615802439/1440138302777987133
local masterKeyToggle = 343

local gdirections = {
  "left & back",
  "right & back",
  "left & right"
}
local gdirection = gdirections[1]

-- whether to use a key to move to the next farming line
local tglChangingDirection = true
-- which direction to move
local changingDirections = {
  "W", "A", "S", "D"
}
local changingDirection = changingDirections[1]

-- options for return direction: "W" or "A" or "S" or "D"
-- this just means which direction u wanna move in when u are returning hence restarting the farm
-- this is triggered when u are standing over the
-- "returnBlockBelowFeet" block (look at the bottom of config)
local returnDirection = "S"

-- toggle stuff to do
local tglSpray = true -- use spray on plots automatically or not
local tglRodSwap = true -- swap pets for spawning pests when pest cooldown is almost ready or not

-- slot numbers should be 1 less than what u think they are
-- like the sb menu is in slot 9 but here we'd put it "8"
local toolSlot = 0
local rodSwapSlot = 2
local spraySlot = 4

-- NOTEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
-- non case sensitive (capitalization doesn't matter)
-- you need 2 auto pet rules whenever u cast rod for these 2 pets
-- what pet to switch to when pest cooldown is close to ready
local pestSpawnPet = "blaze"
-- what pet to switch to when farming (pest cooldown is above 5 seconds)
local farmPet = "lion"

-- yaw and pitch u want to farm at
local gyaw = -90
local gpitch = 0

-- the player Y level when u are standing in the bottom most location in the farm
local groundHeightMin = 67
-- same but top most layer's Y number
local groundHeightMax = 69

-- the amount of pests when you want to start killing them
local pestsToStartKill = 1

local returnBlockBelowFeet = "redstone_block"

-- ignore these
-- local turnAxis = -238.700
-- local turnAxis2 = 237.700

-- config end ------------------------------------------------------------------

-- TODO: fix aim when not correct
-- TODO: fix script not stopping moving/attacking when toggled (same but doesn't stop at all when killing pests)

gut.tgl.pest = true
gut.tgl.pestCd = true
gut.tgl.spray = true
gut.tgl.visitors = true
gut.tgl.velocity = true
gut.tgl.blockBelowFeet = true
gut.tgl.pet = true
gui.config.gapInLinesFromTop = 0

pest_fly.setState("Stop")
rotations.setRotationSpeed(5)
local delayer = 0
local homeSet = false
local wasKilling = false
local farmingDelayer = 0
local mainToggle = false
local spray = "default"
local sprayTime = 0
local wasKillingState = "left"
local wasMoving = false
-- local pestCooldown = 0

local function toggleSys()
  mainToggle = not mainToggle
  gog.info("toggled " .. (mainToggle and "on" or "off"))
end

function readAll(file)
  local f = io.open(file, "r")
  if not f then
    print("Error opening file: " .. (err or "unknown"))
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

-- local icon = ".\\config\\hypixelcry\\scripts\\images\\logo.png"

-- local config_raw = readAll("config/hypixelcry/scripts/data/farming.json")
-- local config = json.parse(config_raw)

local last_pos = nil
local time_between_updates = 0.02
local ready = false
local function getReady()

  local failed = false

  local tool = inventory_utils.findItemByDisplayNameInHotbar("bountiful")
  if tool and tool > -1 then
    toolSlot = tool
    gog.info("hoe/axe slot set to - " .. tostring(tool))
    done = true
  else
    mainToggle = false
    failed = true
    gog.error("no bountiful hoe/axe found in hotbar")
  end

  local sprayy = inventory_utils.findItemByDisplayNameInHotbar("sprayonator")
  if tglSpray then
    if sprayy and sprayy > -1 then
      spraySlot = sprayy
      gog.info("spray slot set to - " .. tostring(sprayy))
    else
      mainToggle = false
      failed = true
      gog.error("no sprayonator found in hotbar, either get one in hotbar or toggle auto-spray off")
    end
  end

  local rodd = inventory_utils.findItemByDisplayNameInHotbar("rod")
  if tglRodSwap then
    if rodd and rodd > -1 then
      rodSwapSlot = rodd
      gog.info("rod slot set to - " .. tostring(rodd))
    else
      mainToggle = false
      failed = true
      gog.error("no rod found in hotbar, either get one in hotbar or toggle rod-swap off")
    end
  end

  local vac = inventory_utils.findItemByDisplayNameInHotbar("vacuum")
  if vac and vac > -1 then
    pest_fly.slotVacuum = vac
    gog.info("vacuum slot set to - " .. tostring(vac))
  else
    mainToggle = false
    failed = true
    gog.error("no vacuum found in hotbar")
  end

  if not failed then
    ready = true
  end

end

local state = "left"
local lastState = "left"
local stopped = false
local teleported = false

local macroStartTime = nil -- Время начала работы макроса на точке
local totalMacroTime = 0 -- Общее время работы макроса
macroStartTime = os.time()

local started = false
local scriptStopped = false

local clockEmojis = {"🕐","🕑","🕒","🕓","🕔","🕕","🕖","🕗","🕘","🕙","🕚","🕛"}
local emojiIndex = 1
local emojiChangeDelay = 10  -- количество тиков между сменой эмодзи
local emojiTick = 0

registerServerSideRotationEvent(function(yaw, pitch)
  if yaw and pitch then
    if (yaw ~= gyaw and pitch ~= gpitch) and
      (pitch ~= 0 and yaw ~= 0) and
      (pitch ~= 0 and yaw ~= 90) and
      (pitch ~= 0 and yaw ~= 180) and
      (pitch ~= 0 and yaw ~= 135) and
      (pitch ~= 0 and yaw ~= 270)
    then
      gog.critical("you got rotated")
      notifications.snowNotifty("Farm Macro", "You got rotated!")
    end
  end
end)

registerServerSideTeleportEvent(function(x, y, z)
  if x and y and z then
    if state2 == "Farming" then
      notifications.snowNotifty("Farm Macro", "You got teleported!")
    end
  end
end)

local state2 = "Farming"

register2DRenderer(function()

  local status = "§a✔"

  if pest_fly.getState() ~= "Stop" then status = "§c🗡" end

  local guiContent = {
    { text = mainToggle and "§2enabled " .. status or "§cdisabled" },
    { text = "§c🦗 " .. pest_fly.getAlivePests() .. " 🗡 " .. pest_fly.getPestsKilled() .. " 👨 " .. gut.inf.visitors },
    { text = "pet: " .. tostring(gut.inf.pet) },
    { text = "pest cd: " .. gut.inf.pestCd },
    { text = "spray: " .. gut.inf.spray },
    { text = "[ Debug ]" },
    -- { text = "pest status: " .. pest_fly.getState() },
    -- { text = "vel: " .. (gut.inf.velocity or "idk") },
    -- { text = "anyScreen: " .. gut.dump.anyScreen },
    -- { text = "chest: " .. "-" ..gut.dump.chestTitle .. "-" .. " | " .. gut.dump.chestSlots },
    -- { text = "slot: " .. (gut.dump.chestItem or "idk") .. " | " .. (gut.dump.chestItemFromContainer or "idk") },
    -- { text = "setPet: " .. tostring(gut.dump.setPet) .. " | " .. tostring(gut.dump.setPetCd) .. " | " .. tostring(gut.dump.setPet_petsCmdCd) },
    -- { text = "pestAlive: " .. (gut.inf.pestAlive or "idk") },
    -- { text = "pestCdRaw: " .. (gut.dump.pestCdRaw or "idk") .. " | " .. type(gut.inf.pestCdRaw) },
    -- { text = "pestCd: " .. (gut.inf.pestCd or "idk") },
    -- { text = "pos: " .. (gut.inf.pos.x or "idk") .. ", " .. (gut.inf.pos.y or "idk") .. ", " .. (gut.inf.pos.z or "idk") },
    { text = "block: " .. (gut.inf.blockBelowFeet or "idk") },
    { text = "state: " .. (state or "idk") },
    { text = "state2: " .. (state2 or "idk") }
  }
  gui.content = guiContent

end)

local timer = 0
local tickForward = 0

registerLocationChangeEvent(function(location)
  if location ~= "Garden" then
    if state2 ~= "RecconectDelay" and state2 ~= "PlayDelay" then
      pest_fly.setState("Stop")
      state2 = "RecconectDelay"
    end
  else
    state2 = "Farming"
  end
end)

registerClientTickPost(function()

  local tabBody = player.getTab()
  if tabBody then tabBody = tabBody.body end
  if not tabBody then return end


  if mainToggle ~= true then
    pest_fly.setState("Stop")
    if wasMoving then
      gut.playerInputStopAll()
      wasMoving = false
    end
    return
  end

  wasMoving = true

  if not ready then
    getReady()
    return
  end

  rotations.update()

  local pos = player.getPos()
  local position = player.getLocation()  -- обновляем location каждый тик

  if position == "GARDEN" and pest_fly.getState() == "Stop" then

    if state2 == "Farming" then
      tickForward = 0
      if wasKilling == true then
        farmingDelayer = farmingDelayer + 1
        if farmingDelayer < 18 then return end
        wasKilling = false
        state = wasKillingState
        gog.debug("wasKilling idk")
        player.input.setSelectedSlot(toolSlot)
      end

      if tglSpray and gut.inf.spray == "None" then
        sprayTime = sprayTime + 1
        if sprayTime < 29 then goto sprayIDK end
        if gut.inf.spray ~= "None" then sprayTime = 0 goto sprayIDK end
        player.input.setPressedAttack(false)
        if sprayTime < 35 then goto sprayIDK end
        gog.debug("sprayed")
        player.input.silentUse(spraySlot)
        sprayTime = 0
      end
      ::sprayIDK::

      if pest_fly.getPestPlots() >= pestsToStartKill then
        delayer = delayer + 1
        if delayer < 5 then return end
        player.input.setPressedRight(false)
        player.input.setPressedLeft(false)
        player.input.setPressedForward(false)
        player.input.setPressedBack(false)
        player.input.setPressedAttack(false)
        player.input.setPressedUse(false)
        if delayer < 10 then return end

        -- if gut.inf.pet ~= pestPet then
        --   if not gut.onCooldown("petSwap", 40) then
        --     player.input.silentUse(rodSwapSlot)
        --   end
        --   return
        -- end

        if delayer < 35 then return end
        player.input.setPressedUse(false)
        if homeSet == false then player.sendCommand("/sethome") homeSet = true end
        -- notifications.snowNotifty("Farm Macro", "Start killing shiters!")
        gog.info("killing pests")
        pest_fly.setState("Teleport")
        rotations.stop()
        delayer = 0
        homeSet = false
        wasKilling = true
        wasKillingState = state
        farmingDelayer = 0
        return false
      end
      -- if math.floor(pos.x) == config.warp.x and math.floor(pos.z) == config.warp.z and not teleported then
      --   player.input.setPressedRight(false)
      --   player.input.setPressedLeft(false)
      --   player.input.setPressedForward(false)
      --   player.input.setPressedAttack(false)
      --   player.input.setPressedUse(false)
      --   pest_fly.setState("Teleport")
      --   notifications.snowNotifty("Farm Macro", "Start killing shiters!", icon)
      --   player.addMessage("killing pests 2")
      --   rotations.stop()
      --   return false
      -- end
      if pos.y >= groundHeightMin or pos.y <= groundHeightMax then

        if tglRodSwap and gut.inf.pestCd <= 5 and string.lower(gut.inf.pet) ~= string.lower(pestSpawnPet) then
          if not gut.onCooldown("petSwap", 40) then
            player.input.silentUse(rodSwapSlot)
          end
        elseif tglRodSwap and gut.inf.pestCd > 10 and string.lower(gut.inf.pet) ~= string.lower(farmPet) then
          if not gut.onCooldown("petSwap", 40) then
            player.input.silentUse(rodSwapSlot)
          end
        end

        if not player.isOnGround() then
          player.input.setPressedSneak(true)
        else
          player.input.setPressedSneak(false)
        end

        teleported = false
        grounded = true
        stopped = false
        if last_pos ~= nil then
          local dx = pos.x - last_pos.x
          local dy = pos.y - last_pos.y
          local dz = pos.z - last_pos.z

          local speed_x = dx / time_between_updates
          local speed_y = dy / time_between_updates
          local speed_z = dz / time_between_updates

          local total_speed = math.sqrt(speed_x*speed_x + speed_y*speed_y + speed_z*speed_z)

          if total_speed <= 0.0 and not player.inventory.isAnyScreenOpened() then
            -- if pos.z ~= turnAxis or pos.z ~= turnAxis2 then goto alright end
            -- if gut.onCooldown("turning", 15) then return end
            -- player.addMessage("turning")
            if gut.inf.blockBelowFeet == returnBlockBelowFeet then
              state = "return"
              goto alright
            -- elseif state == "left" then
            --   state = "right"
            -- elseif state == "right" then
            --   state = "left"
            elseif state == "changing" then
              if lastState == "left" then
                state = "right"
              elseif lastState == "right" then
                state = "left"
              end
            elseif tglChangingDirection then
              lastState = state
              state = "changing"
            elseif state == "left" then
              state = "right"
            elseif state == "right" then
              state = "left"
            end
          end
        end
        ::alright::

        -- player.input.setSelectedSlot(0)
        player.input.setPressedSprinting(true)
        -- player.input.setPressedForward(true)
        player.input.setPressedAttack(true)
        -- gog.debug("setPressedAttack")
        if state == "left" then

          if gdirection == "right & back" then
            player.input.setPressedLeft(false)
            player.input.setPressedForward(false)
            player.input.setPressedBack(true)
            player.input.setPressedRight(false)
          end
          if gdirection == "left & back" then
            player.input.setPressedLeft(true)
            player.input.setPressedForward(false)
            player.input.setPressedBack(false)
            player.input.setPressedRight(false)
          end
          if gdirection == "left & right" then
            player.input.setPressedLeft(true)
            player.input.setPressedForward(false)
            player.input.setPressedBack(false)
            player.input.setPressedRight(false)
          end

        elseif state == "right" then

          if gdirection == "right & back" then
            player.input.setPressedLeft(false)
            player.input.setPressedForward(false)
            player.input.setPressedBack(false)
            player.input.setPressedRight(true)
          end
          if gdirection == "left & back" then
            player.input.setPressedLeft(false)
            player.input.setPressedForward(false)
            player.input.setPressedBack(true)
            player.input.setPressedRight(false)
          end
          if gdirection == "left & right" then
            player.input.setPressedLeft(false)
            player.input.setPressedForward(false)
            player.input.setPressedBack(false)
            player.input.setPressedRight(true)
          end

        elseif state == "changing" then

          if changingDirection == "W" then
            player.input.setPressedLeft(false)
            player.input.setPressedForward(true)
            player.input.setPressedBack(false)
            player.input.setPressedRight(false)
          end
          if changingDirection == "A" then
            player.input.setPressedLeft(true)
            player.input.setPressedForward(false)
            player.input.setPressedBack(false)
            player.input.setPressedRight(false)
          end
          if changingDirection == "S" then
            player.input.setPressedLeft(false)
            player.input.setPressedForward(false)
            player.input.setPressedBack(true)
            player.input.setPressedRight(false)
          end
          if changingDirection == "D" then
            player.input.setPressedLeft(false)
            player.input.setPressedForward(false)
            player.input.setPressedBack(false)
            player.input.setPressedRight(true)
          end

        elseif state == "return" then

          if returnDirection == "W" then
            player.input.setPressedLeft(false)
            player.input.setPressedForward(true)
            player.input.setPressedBack(false)
            player.input.setPressedRight(false)
          end
          if returnDirection == "A" then
            player.input.setPressedLeft(true)
            player.input.setPressedForward(false)
            player.input.setPressedBack(false)
            player.input.setPressedRight(false)
          end
          if returnDirection == "S" then
            player.input.setPressedLeft(false)
            player.input.setPressedForward(false)
            player.input.setPressedBack(true)
            player.input.setPressedRight(false)
          end
          if returnDirection == "D" then
            player.input.setPressedLeft(false)
            player.input.setPressedForward(false)
            player.input.setPressedBack(false)
            player.input.setPressedRight(true)
          end

        end
        last_pos = pos
      elseif stopped == false then
        player.input.setPressedRight(false)
        player.input.setPressedLeft(false)
        player.input.setPressedForward(false)
        player.input.setPressedAttack(false)
        stopped = true
      else
        grounded = false
        rotated = false
      end
      if grounded and not rotated then
        rotations.rotateToYawPitch(gyaw, gpitch)
        rotated = true
      end
    end
  else
    if stopped == false then
      player.input.setPressedRight(false)
      player.input.setPressedLeft(false)
      player.input.setPressedForward(false)
      player.input.setPressedAttack(false)
      player.input.setPressedUse(false)
      stopped = true
    end

    if state2 == "RecconectDelay" then
      tickForward = tickForward + 1
      if tickForward <= 570 and not player.isOnSkyBlock() then
        --player.addMessage("Lobby timer: " .. tickForward)
      else
        state2 = "PlayDelay"
        player.sendCommand("/lobby")
        tickForward = 0
      end
    elseif state2 == "PlayDelay" then
      tickForward = tickForward + 1
      if tickForward <= 570 and not player.isOnSkyBlock()  then
        --player.addMessage("Play timer: " .. tickForward)
      else
        state2 = "LobbyDelay"
        player.sendCommand("/play skyblock")
        tickForward = 0
      end
    elseif state2 == "LobbyDelay" then
      tickForward = tickForward + 1
      if tickForward <= 570 then
        --player.addMessage("Warp timer: " .. tickForward)
      else
        state2 = "Farming"
        stopped = false
        player.sendCommand("/warp garden")
        -- player.addMessage("farming now")
        tickForward = 0
      end
    end
    state = "left"
  end

end)

registerKeyEvent(function(key, action)
  if key == masterKeyToggle and action == "Release" then
    toggleSys()
  end
end)

-- cryvigilance cvp ------------------------------------------------------------

-- cv opts
local cvo = {
  cat = "goonFarming",
  subc = {
    main = "main",
    directions = "directions",
    greturn = "return",
    pet = "pet",
    camera = "camera",
    spray = "spray",
    misc = "misc",
    dev = "dev"
  }
}

local cfg = cv.new(
    "goon",
    "goon",
    nil,
    345
)

cfg:addProperty({
  type        = cv.TYPES.SWITCH,
  key         = "mainToggle",
  name        = "toggle",
  description = "turns on/off (keybind: windows-key)",
  category    = cvo.cat,
  subcategory = cvo.subc.main,
  default     = false,
})
cfg:onChanged("mainToggle", function(newValue)
  mainToggle = newValue
end)
cfg:addProperty({
    type        = cv.TYPES.SLIDER,
    key         = "pestsToStartKill",
    name        = "pests to start killing",
    description = "amount of pests that should be alive before starting to kill them",
    category    = cvo.cat,
    subcategory = cvo.subc.main,
    default     = 2,
    min         = 1,
    max         = 8,
})
cfg:onChanged("pestsToStartKill", function(newValue)
  pestsToStartKill = newValue
end)

cfg:addProperty({
  type        = cv.TYPES.SWITCH,
  key         = "tglSpray",
  name        = "auto-spray",
  description = "turns on/off auto-spray plot",
  category    = cvo.cat,
  subcategory = cvo.subc.spray,
  default     = false,
})
cfg:onChanged("tglSpray", function(newValue)
  tglSpray = newValue
end)

cfg:addProperty({
    type          = cv.TYPES.DECIMAL_SLIDER,
    key           = "gyaw",
    name          = "yaw",
    description   = "yaw to look at when farming (ctrl-click to enter manually)",
    category      = cvo.cat,
    subcategory   = cvo.subc.camera,
    default       = 0.0,
    minF          = -179.9,
    maxF          = 180.0,
    decimalPlaces = 1,
})
cfg:onChanged("gyaw", function(newValue)
  gyaw = newValue
end)
cfg:addProperty({
    type          = cv.TYPES.DECIMAL_SLIDER,
    key           = "gpitch",
    name          = "pitch",
    description   = "pitch to look at when farming (ctrl-click to enter manually)",
    category      = cvo.cat,
    subcategory   = cvo.subc.camera,
    default       = 0.0,
    minF          = -90.0,
    maxF          = 90.0,
    decimalPlaces = 1,
})
cfg:onChanged("gpitch", function(newValue)
  gpitch = newValue
end)

cfg:addProperty({
  type        = cv.TYPES.SWITCH,
  key         = "tglRodSwap",
  name        = "rod swap pet",
  description = "turns on/off auto-swap pet for pest spawning and back to cow when farming",
  category    = cvo.cat,
  subcategory = cvo.subc.pet,
  default     = false,
})
cfg:onChanged("tglRodSwap", function(newValue)
  tglRodSwap = newValue
end)
cfg:addProperty({
    type        = cv.TYPES.TEXT,
    key         = "pestSpawnPet",
    name        = "petname",
    description = "petname for spawning pests (slug/mosquito)",
    category    = cvo.cat,
    subcategory = cvo.subc.pet,
    default     = "slug",
    placeholder = "slug / mosquito",
})
cfg:onChanged("pestSpawnPet", function(newValue)
  pestSpawnPet = newValue
end)
cfg:addProperty({
    type        = cv.TYPES.TEXT,
    key         = "farmPet",
    name        = "petname",
    description = "petname for farming",
    category    = cvo.cat,
    subcategory = cvo.subc.pet,
    default     = "mooshroom cow",
    placeholder = "cow / elephant / rabbit",
})
cfg:onChanged("farmPet", function(newValue)
  farmPet = newValue
end)

cfg:addProperty({
  type        = cv.TYPES.SELECTOR,
  key         = "gdirection",
  name        = "moving direction",
  description = "direction to move in while farming",
  category    = cvo.cat,
  subcategory = cvo.subc.directions,
  default     = 1,
  options     = gdirections
})
cfg:onChanged("gdirection", function(newIdx)
  gdirection = gdirections[newIdx]
end)

cfg:addProperty({
  type        = cv.TYPES.SWITCH,
  key         = "tglChangingDirection",
  name        = "change lanes ?",
  description = "turns on/off changing lane movement",
  category    = cvo.cat,
  subcategory = cvo.subc.directions,
  default     = false,
})
cfg:onChanged("tglChangingDirection", function(newValue)
  tglChangingDirection = newValue
end)
cfg:addProperty({
  type        = cv.TYPES.SELECTOR,
  key         = "changingDirection",
  name        = "lane changing direction",
  description = "direction to move in to move to next lane",
  category    = cvo.cat,
  subcategory = cvo.subc.directions,
  default     = 1,
  options     = changingDirections
})
cfg:onChanged("changingDirection", function(newIdx)
  changingDirection = changingDirections[newIdx]
end)

cfg:addProperty({
  type        = cv.TYPES.SELECTOR,
  key         = "returnDirection",
  name        = "restart direction",
  description = "direction to move in when restarting farm",
  category    = cvo.cat,
  subcategory = cvo.subc.greturn,
  default     = 1,
  options     = changingDirections
})
cfg:onChanged("returnDirection", function(newIdx)
  returnDirection = changingDirections[newIdx]
end)
cfg:addProperty({
    type        = cv.TYPES.TEXT,
    key         = "returnBlockBelowFeet",
    name        = "block name",
    description = "block to detect for restarting farm",
    category    = cvo.cat,
    subcategory = cvo.subc.greturn,
    default     = "",
    placeholder = "redstone_block...",
})
cfg:onChanged("returnBlockBelowFeet", function(newValue)
  returnBlockBelowFeet = newValue
end)

cfg:addProperty({
  type        = cv.TYPES.SLIDER,
  key         = "groundHeightMin",
  name        = "lowest farming Y level",
  description = "the lowest Y level of the farm",
  category    = cvo.cat,
  subcategory = cvo.subc.misc,
  default     = 67,
  min         = 67,
  max         = 77,
})
cfg:onChanged("groundHeightMin", function(newValue)
  groundHeightMin = newValue
end)
cfg:addProperty({
  type        = cv.TYPES.SLIDER,
  key         = "groundHeightMax",
  name        = "highest farming Y level",
  description = "the highest Y level of the farm (lowest + 1 if your farm is flat)",
  category    = cvo.cat,
  subcategory = cvo.subc.misc,
  default     = 69,
  min         = 67,
  max         = 77,
})
cfg:onChanged("groundHeightMax", function(newValue)
  groundHeightMax = newValue
end)
cfg:addProperty({
  type        = cv.TYPES.SLIDER,
  key         = "flyY",
  name        = "pest killing Y level",
  description = "the Y level to fly at when killing pests",
  category    = cvo.cat,
  subcategory = cvo.subc.misc,
  default     = 77,
  min         = 67,
  max         = 80,
})
cfg:onChanged("groundHeightMax", function(newValue)
  pest_fly.flyY = newValue
end)

cfg:addProperty({
  type        = cv.TYPES.SWITCH,
  key         = "logDebug",
  name        = "log debug",
  description = "logs debug messages",
  category    = cvo.cat,
  subcategory = cvo.subc.dev,
  default     = false,
})
cfg:onChanged("logDebug", function(newValue)
  gog.config.logTypes.debug.enabled = newValue
end)

cfg:initialize()

-- cryvigilance end ------------------------------------------------------------

