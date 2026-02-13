local idk = "idk"
-- local regexPetNameInTab = "%[Lvl %d+%] (.+)"
local regexPetNameInPetsMenu = "%[Lvl %d+%] (.+)%]"
local regexPetNameInAutopet = "%[Lvl %d+%]%s+(.-)!"
local regexPetNameInManualSummon = "You summoned your (.-)!"

-- inf stands for info but i like 3 letter words for naming so cope with it
---@class inf
---@field location string
---@field pet string
---@field visitors number | string | nil
---@field spray string | nil
---@field pestCd number | string | nil
---@field pos {x: number, y: number, z: number}
---@field velocity number | string
---@field blockBelowFeet string

---@class All
---@field inf inf
local all = {
  inf = {
    location = idk,
    pet = idk,
    visitors = "idk",
    spray = "idk",
    pestCd = "idk",
    pos = {0,0,0},
    velocity = idk,
    blockBelowFeet = idk
  },
  clr = {
    green = "§a",
    red = "§c",
    white = "§7"
  },
  dump = {},
  tmp = {},
  _cds = {},
  _wtr = {}
}

--------------------------------------------------------------------------------

---@param string string
---@return nil
local function grint(string)
  print("[goon] " .. string)
end

--------------------------------------------------------------------------------

---@param table table
---@return string
function all.tableToString(table)
    local result = "{ "
    local first = true

    for k, v in pairs(table) do
        if not first then result = result .. ", " end
        -- Format as "key = value"
        result = result .. tostring(k) .. " = " .. tostring(v)
        first = false
    end

    return result .. " }"
end

--------------------------------------------------------------------------------

---@param prefix string
---@param list table
---@return table
function all.addPrefixToATableOfStrings(prefix, list)
  local ret = {}
  for _, name in ipairs(list) do
    ret[prefix .. name] = true
  end
  return ret
end

--------------------------------------------------------------------------------

---@param label string
---@param isPressed function
---@param showValue boolean | nil
---@return string
function all.getColoredStatusInStringOfAFunction(label, isPressed, showValue)
  local color = isPressed and all.clr.green or all.clr.red
  local str = color .. label
  if not showValue then return str end
  if isPressed == nil then return str end
  str = str .. all.clr.white .. ": " .. tostring(isPressed)
  return str
end

--------------------------------------------------------------------------------

---@param hRange number
---@param vRange number
---@param excludeEntities table
function all.getNearbyEntities(hRange, vRange, excludeEntities)

  local mobList = {}
  local playerPos = player.getPos()
  if not playerPos then return mobList end

  for _, entity in ipairs(world.getEntities()) do

    -- skip the local player
    if entity
    and entity.uuid ~= player.entity.uuid
    and not excludeEntities[entity.type]
    then
      local ex, ey, ez = entity.x, entity.y, entity.z

      -- calculate distances
      local horizontalDist = math.sqrt((playerPos.x - ex)^2 + (playerPos.z - ez)^2)
      local verticalDist = math.abs(playerPos.y - ey)

      -- check if within defined ranges
      if horizontalDist <= hRange and verticalDist <= vRange then
        table.insert(mobList, {
          name = entity.display_name or entity.name or "Unknown",
          type = entity.type or "Unknown",
          uuid = entity.uuid,
          hDist = math.floor(horizontalDist * 10) / 10, -- rounded to 1 decimal
          vDist = math.floor(verticalDist * 10) / 10,
          pos = {x = ex, y = ey, z = ez}
        })
      end
    end
  end
  return mobList
end

--------------------------------------------------------------------------------

function all.onCooldown(uid, ticks)
  if all._cds[uid] and all._cds[uid] > 0 then return true -- is on cd
  else all._cds[uid] = ticks return false end -- not on cd, allow shit to run
end
local function updateCooldown()
  for key, ticks in pairs(all._cds) do
    if ticks > 0 then all._cds[key] = ticks - 1
    else all._cds[key] = nil end
  end
end

--------------------------------------------------------------------------------

local function strip(s)
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end

---@param text string
---@param lore table
---@param itrInReverse boolean
---@return boolean
local function isTextInLore(text, lore, itrInReverse)

  local start = itrInReverse and #lore or 1
  local stop = itrInReverse and 1 or #lore
  local step = itrInReverse and -1 or 1

  for x = start, stop, step do
    local line = removeMinecraftColors(lore[x])
    if line:find(text, 1, true)  then
      do return true end
    end
  end
  return false
end

--------------------------------------------------------------------------------

---@param s string
---@return integer
local function _handleTimeNumbers(s)
  if s == "MAX PESTS" then return -1 end
  if s == "READY" then return 0 end
  local min = s:match("(%d*)m") or 0
  local sec = s:match("(%d+)s") or 0
  return (tonumber(min) * 60) + tonumber(sec)
end

local function _getTabInfo(key, line, regex, fallbackValue, isNumber, dump)
  local match = line:match(regex)
  if not match then return end

  local value = isNumber and (tonumber(match) or fallbackValue) or match
  local lastKey = "last" .. key .. "FromGetTabInfo"
  if all.dump[lastKey] == value then return end

  if not dump then all.inf[key] = value or fallbackValue
  else all.dump[key] = value or fallbackValue end
  all.dump[lastKey] = value
end

local function getTabInfo(player)

  local tabBody = (player.getTab()).body
  if not tabBody then return end
  for _, lineRaw in ipairs(tabBody) do

    local line = removeMinecraftColors(lineRaw)

    -- global
    _getTabInfo("pet", line, regexPetNameInTab)

    -- garden
    _getTabInfo("visitors", line, "Visitors: %((%d+)%)", idk)
    _getTabInfo("spray", line, "Spray: (.+)", idk)
    _getTabInfo("pestAlive", line, "Alive: (%d)", -1, true)

    _getTabInfo("pestCdRaw", line, "Cooldown: (.*)", "MAX PESTS", false, true)
    if all.dump.pestCdRaw then
      all.inf.pestCd = _handleTimeNumbers(all.dump.pestCdRaw)
    end

    -- test stuff
    -- any screen is open boolean
    -- local lineAnyScreen = player.inventory.isAnyScreenOpened()
    -- all.dump.anyScreen = tostring(lineAnyScreen)
    -- chestTitle, string | nil
    -- local lineChestTitle = player.inventory.getChestTitle()
    -- all.dump.chestTitle = tostring(lineChestTitle)
    -- local lineChestSlots = tostring(player.inventory.getContainerSlots())
    -- all.dump.chestSlots = tostring(lineChestSlots)
    -- local lineChestItemFromContainer = player.inventory.getStackFromContainer(7)
    -- if lineChestItemFromContainer then all.dump.chestItemFromContainer = tostring(lineChestItemFromContainer.name) end
    -- local lineChestItem = player.inventory.getStack(10)
    -- if lineChestItem then all.dump.chestItem = tostring(lineChestItem.name) end

  end
end

--------------------------------------------------------------------------------

---@return string | nil
local function _getBlockBelowFeet(world)
  if type(all.inf.pos) ~= "table" then return end
  local x, y, z = all.inf.pos.x, all.inf.pos.y, all.inf.pos.z
  local blk = (world.getBlock(x-1,y-1,z-0.5)).name
  local ret = blk:match("block%.minecraft.(.*)")
  return ret
end

--------------------------------------------------------------------------------

---@param txt string
---@return string | nil
local function updatePetFromManualSummon(txt)
  local match = txt:match(regexPetNameInManualSummon)
  local ret = nil
  if match then
    ret = tostring(match)
  end
  return ret or nil
end

---@param txt string
---@return string | nil
local function updatePetFromAutopet(txt)
  local match = txt:match(regexPetNameInAutopet)
  local ret = nil
  if match then
    ret = tostring(match)
  end
  return ret
end

--------------------------------------------------------------------------------

local function _playerInputStopAll(player)
  player.input.setPressedForward(false)
  player.input.setPressedBack(false)
  player.input.setPressedLeft(false)
  player.input.setPressedRight(false)
  player.input.setPressedJump(false)
  player.input.setPressedSprint(false)
  player.input.setPressedSneak(false)
  player.input.setPressedAttack(false)
  player.input.setPressedUse(false)
  if all.inf.velocity < 0.5 then
    all.dump.playerInputStopAllValue = false
    player.addMessage("stopped")
  end
end
function all.playerInputStopAll()
  all.dump.playerInputStopAllValue = true
end

--------------------------------------------------------------------------------

local function getVelocity()

  local pos = all.inf.pos
  if not pos then return 0 end
  local lpos = all.dump.last_pos
  if not lpos then
    all.dump.last_pos = { x = pos.x, y = pos.y, z = pos.z }
    return 0
  end

  local dx = pos.x - lpos.x
  local dy = pos.y - lpos.y
  local dz = pos.z - lpos.z
  local distance = math.sqrt(dx^2 + dy^2 + dz^2)
  local bps = distance * 20

  ---@type number
  local velocity = math.floor(bps * 100 + 0.5) / 100

  all.dump.last_pos = { x = pos.x, y = pos.y, z = pos.z }
  return velocity
end

--------------------------------------------------------------------------------

-- allows you to swap pet using the /petsmenu inventory
-- it's kinda buggy and slow
-- it does work but rarely leaves the petsmenu open, thus softlocking

---@param petName string
---@return boolean
function all.setPet(petName)

  -- request already satisfied or early exit
  if all.inf.pet == petName then
    return true
  end

  -- handle cooldown
  if all.dump.setPetCd and all.dump.setPetCd > 0 then
    all.dump.setPetCd = all.dump.setPetCd - 1
    return false
  end

  -- existing instance
  if all.dump.setPet == true then
    return false
  end

  -- new instance
  all.dump.setPetName = petName
  all.dump.setPet = true
  return false

end

local function _setPet(player)

  -- request satified
  if all.inf.pet == all.dump.setPetName then
    all.dump.setPet = false
    return
  end

  if all.dump.setPet_petsCmdCd then
    all.dump.setPet_petsCmdCd = all.dump.setPet_petsCmdCd - 1
  end
  local title = player.inventory.getChestTitle()

  -- open pets menu with cooldown
  if title ~= "Pets"
    and
    (
    not all.dump.setPet_petsCmdCd or
    all.dump.setPet_petsCmdCd <= 0
  ) then
    player.sendMessage("/pets")
    all.dump.setPet_petsCmdCd = 60
    return false
  end

  -- iterate through all pets
  for i = 10, 43 do
    local pet = player.inventory.getStackFromContainer(i)
    if not pet then goto skip end
    if pet.name ~= "Player Head" then goto skip end

    local dName = removeMinecraftColors(pet.display_name)
    local name = dName:match(regexPetNameInPetsMenu)
    if not name then goto skip end
    if strip(name) ~= all.dump.setPetName then goto skip end

    if not isTextInLore("Left-click to summon!", pet.lore, true) then
      goto skip
    end

    player.inventory.leftClick(i)
    all.dump.setPet = false
    all.dump.setPet_petsCmdCd = 0
    all.dump.setPetCd = 60

    do return true end
    ::skip::
  end
  return false

end

--------------------------------------------------------------------------------

-- not finished yet btw use onCooldown() instead
---@param ticks number | nil
---@return boolean
function all.waiting(uid, ticks)

  if ticks then
    if not all._wtr[uid] or all._wtr[uid] <= 0 then
      all._wtr[uid] = ticks
      return true
    end
  end

  all._wtr[uid] = all._wtr[uid] - 1

  if all._wtr[uid] <= 0 then
    all._wtr[uid] = 0
    return false
  end
  return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

registerClientTickPost(function()

  updateCooldown()

  -- inf shit
  -- getTabInfo(player)
  all.inf.pos = player.getPos() or idk
  all.inf.velocity = getVelocity() or idk
  all.inf.location = player.getRawLocation() or idk
  all.inf.blockBelowFeet = _getBlockBelowFeet(world) or idk

  -- if all.dump.playerInputStopAllValue == true then
  --   _playerInputStopAll(player)
  -- end

  -- if all.dump.setPet and all.dump.setPet == true then
  --   _setPet(player)
  -- end

end)

--------------------------------------------------------------------------------

registerMessageEvent(function(text, overlay)

  if overlay then return end
  if not text then return end

  -- local txt = removeMinecraftColors(text)

  all.inf.pet = updatePetFromAutopet(text) or idk
  all.inf.pet = updatePetFromManualSummon(text) or idk

  -- if text then print("text: " .. tostring(text)) end
  -- if overlay then print("overlay: " .. tostring(overlay)) end

end)

--------------------------------------------------------------------------------

return all
