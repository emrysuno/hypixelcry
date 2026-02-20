local rotations = require("rotations_v2.lua")
local notifications = require("notifications.lua")
local pest_fly = require("pest_fly.lua")
local gui = require("goonUi.lua")
local gut = require("goonUtils.lua")
local gog = require("goonLog.lua")

-- config ----------------------------------------------------------------------

-- keep this diabled else crash
local tglGui = false

-- key to toggle the script (doesn't stop when its killing pests)
-- find them in this channel https://discord.com/channels/1418100297615802439/1440138302777987133
local masterKeyToggle = 343

local gdirections = {
  "left & back",
  "right & back",
  "left & right"
}
local gdirection = gdirections[2]

-- whether to use a key to move to the next farming line
local tglChangingDirection = false
-- which direction to move
local changingDirections = {
  "W", "A", "S", "D"
}
local changingDirection = 0

-- options for return direction: "W" or "A" or "S" or "D"
-- this just means which direction u wanna move in when u are returning hence restarting the farm
-- this is triggered when u are standing over the
-- "returnBlockBelowFeet" block (look at the bottom of config)
local returnDirection = "W"

-- toggle stuff to do
local tglSpray = false -- use spray on plots automatically or not
local tglRodSwap = false -- swap pets for spawning pests when pest cooldown is almost ready or not

-- slot numbers should be 1 less than what u think they are
-- like the sb menu is in slot 9 but here we'd put it "8"
local toolSlot = 1
local rodSwapSlot = 2
local spraySlot = 3

-- NOTEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
-- non case sensitive (capitalization doesn't matter)
-- you need 2 auto pet rules whenever u cast rod for these 2 pets
-- what pet to switch to when pest cooldown is close to ready
local pestSpawnPet = "Blaze"
-- what pet to switch to when farming (pest cooldown is above 5 seconds)
local farmPet = "Ghoul"

-- yaw and pitch u want to farm at
local gyaw = 135
local gpitch = 16.5

-- the player Y level when u are standing in the bottom most location in the farm
local groundHeightMin = 67
-- same but top most layer's Y number
local groundHeightMax = 69

-- the amount of pests when you want to start killing them
local pestsToStartKill = 9

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
-- local pestCooldown = 0

local function toggleSys()
  mainToggle = not mainToggle
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

-- registerWorldRenderer(function(context)
--   local position = player.getLocation()
--   if position ~= "GARDEN" then return end
--
--   local end_filled = {
--     x = config.warp.x, y = config.warp.y + 1, z = config.warp.z,
--     red = 255, green = 85, blue = 85, alpha = 140,
--     through_walls = true
--   }
--   context.renderFilled(end_filled)
--
--   local end_text = {
--     x = config.warp.x + 0.5, y = config.warp.y + 2.5, z = config.warp.z + 0.5,
--     red = 255, green = 0, blue = 0,
--     scale = 1,
--     text = "End", through_walls = true
--   }
--   context.renderText(end_text)
--
--   local start_filled = {
--     x = config.start.x, y = config.start.y + 1, z = config.start.z,
--     red = 85, green = 255, blue = 85, alpha = 140,
--     through_walls = true
--   }
--   context.renderFilled(start_filled)
--
--   local start_text = {
--     x = config.start.x + 0.5, y = config.start.y + 2.5, z = config.start.z + 0.5,
--     red = 85, green = 255, blue = 85,
--     scale = 1,
--     text = "Start", through_walls = true
--   }
--   context.renderText(start_text)
-- end)

-- local visitors = 0
local state2 = "Farming"

register2DRenderer(function(context)

  local farming_tool = player.inventory.getStack(0)
  local vacuum_tool = player.inventory.getStack(1)
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
    -- { text = "block: " .. (gut.inf.blockBelowFeet or "idk") },
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

function removeMinecraftColors(str)
  return string.gsub(str or "", "§[0-9a-fk-or]", "")
end

function isFirstSlotSelected()
  selectedSlot = player.input.getSelectedSlot()
  if selectedSlot == toolSlot then return true or false end
end

registerClientTickPost(function()

  local tabBody = (player.getTab()).body
  if not tabBody then return end

  -- for _, line in ipairs(tabBody) do
  --   local remLine = removeMinecraftColors(line)
  --
  --   local vis = string.match(remLine, "Visitors: %((%d+)%)")
  --   if vis then visitors = tonumber(vis) or -1 end
  --
  --   local spra = string.match(remLine, "Spray: (.+)")
  --   if spra then spray = tostring(spra) or "undefined" end
  --   local pestCd = string.match(remLine, "Cooldown: (.+)")
  --   if pestCd then pestCooldown = tostring(pestCd) or -1 end
  --   -- local pe = string.match(remLine, "%[Lvl %d+%] (.+)")
  --   -- if pe then pet = tostring(pe) or "undefined" end
  --
  -- end

  if mainToggle ~= true then return end

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
      end

      if tglSpray and spray == "None" then
        sprayTime = sprayTime + 1
        if sprayTime < 29 then return end
        if spray ~= "None" then sprayTime = 0 return end
        player.input.setPressedAttack(false)
        if sprayTime < 35 then return end
        player.input.silentUse(spraySlot)
        sprayTime = 0
      end

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

        player.input.setSelectedSlot(0)
        player.input.setPressedSprinting(true)
        -- player.input.setPressedForward(true)
        player.input.setPressedAttack(true)
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
    gog.info("toggled " .. (mainToggle and "on" or "off"))
  end
end)

registerImGuiRenderEvent(function()

  if not tglGui then return end

  if imgui.begin("goon farming 2") then

    -- checkbox, master toggle
    local mainToggleChanged, mainToggleNew = imgui.checkbox("master toggle", mainToggle)
    if mainToggleChanged then mainToggle = mainToggleNew end

    -- listbox, movement direction
    gdirection = imgui.listBox("ListBox", gdirection, gdirections)

    -- checkbox + listbox, changing direction + toggle
    local tglChangingDirectionChanged, tglChangingDirectionNew = imgui.checkbox("change lane", tglChangingDirection)
    if tglChangingDirectionChanged then tglChangingDirection = tglChangingDirectionNew end
    changingDirection = imgui.listBox("change lane direction", changingDirection, changingDirections)

    returnDirection = imgui.listBox("restart direction", returnDirection, changingDirections)

    local tglRodSwapChanged, tglRodSwapNew = imgui.checkbox("pet swap", tglRodSwap)
    if tglRodSwapChanged then tglRodSwap = tglRodSwapNew end

    local tglSprayChanged, tglSprayNew = imgui.checkbox("spray plot", tglSpray)
    if tglSprayChanged then tglSpray = tglSprayNew end

    local hoe, hoeNew = imgui.inputInt("hoe slot", toolSlot, 1, 1)
    if hoe then
      if hoeNew > 0 and hoeNew < 10 then
        toolSlot = hoeNew
      end
    end

    local rod, rodNew = imgui.inputInt("rod slot", rodSwapSlot, 1, 1)
    if rod then
      if rodNew > 0 and rodNew < 10 then
        rodSwapSlot = rodNew
      end
    end

    local sprayy, spraynew = imgui.inputInt("spray slot", spraySlot, 1, 1)
    if sprayy then
      if spraynew > 0 and spraynew < 10 then
        spraySlot = spraynew
      end
    end

    local pestSpawnPetChanged, pestSpawnPetNew = imgui.inputText("pest spawn pet", pestSpawnPet)
    if pestSpawnPetChanged then pestSpawnPet = pestSpawnPetNew end

    local farmPetChanged, farmPetNew = imgui.inputText("farm pet", farmPet)
    if farmPetChanged then farmPet = farmPetNew end

    local yaww, yawwNew = imgui.inputInt("yaw", gyaw, 15, 45)
    if yaww then
      if yawwNew >= -180.0 and yawwNew <= 179.9 then
        gyaw = yawwNew
      end
    end

    local pitchh, pitchhNew = imgui.inputFloat("pitch", gpitch, 15, 45, "%.3f")
    if pitchh then
      if pitchhNew >= -90 and pitchhNew <= 90 then
        gpitch = pitchhNew
      end
    end

    local ghmc, ghmcn = imgui.inputInt("lowest farm Y", groundHeightMin, 1, 8)
    if ghmc then
      if ghmcn >= -180 and ghmcn <= 180 then
        groundHeightMin = ghmcn
      end
    end
    local ghMc, ghMcn = imgui.inputInt("highest farm Y", groundHeightMax, 1, 8)
    if ghMc then
      if ghMcn >= -180 and ghMcn <= 180 then
        groundHeightMax = ghMcn
      end
    end

    local ptsk, ptskn = imgui.inputInt("pests to start killing", pestsToStartKill, 1, 1)
    if ptsk then
      if ptskn >= 1 and ptskn <= 8 then
        pestsToStartKill = ptskn
      end
    end

    local rtbf, rtbfn = imgui.inputText("block to detect below feet for restart", returnBlockBelowFeet)
    if rtbf then returnBlockBelowFeet = rtbfn end

  end

  imgui.endBegin()

end)
