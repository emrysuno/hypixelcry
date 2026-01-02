local idk = "idk"
local regexPetNameInTab = "%[Lvl %d+%] (.+)"
local regexPetNameInPetsMenu = "%[Lvl %d+%] (.+)%]"
local regexPetNameInAutopet = "%[Lvl %d+%]%s+(.-)!"
local regexPetNameInManualSummon = "You summoned your (.-)!"

-- inf stands for info but i like 3 letter words for naming so cope with it
---@class inf
---@field pet string | nil
---@field visitors number | string | nil
---@field spray string | nil
---@field pestCd number | string | nil
---@field pos {x: number, y: number, z: number} | string | nil
---@field velocity number | string | nil

---@class All
---@field inf inf
local all = {
  inf = {
    pet = "idk",
    visitors = "idk",
    spray = "idk",
    pestCd = "idk",
    pos = "idk",
    velocity = "idk"
  },
  dump = {},
  cds = {}
}

--------------------------------------------------------------------------------

---@param string string
---@return nil
local function grint(string)
  print("[goon] " .. string)
end

--------------------------------------------------------------------------------

function all.onCooldown(uid, ticks)
  if all.cds[uid] and all.cds[uid] > 0 then return true -- is on cd
  else all.cds[uid] = ticks return false end -- not on cd, allow shit to run
end
local function updateCooldown()
  for key, ticks in pairs(all.cds) do
    if ticks > 0 then all.cds[key] = ticks - 1
    else all.cds[key] = nil end
  end
end

--------------------------------------------------------------------------------

local function strip(s)
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end

---@param text string
---@param lore table
---@param reverseIteration boolean
---@return boolean
local function isTextInLore(text, lore, reverseIteration)

  local start = reverseIteration and #lore or 1
  local stop = reverseIteration and 1 or #lore
  local step = reverseIteration and -1 or 1

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
    -- _getTabInfo("pet", line, regexPetNameInTab)

    -- garden
    _getTabInfo("visitors", line, "Visitors: %((%d+)%)")
    _getTabInfo("spray", line, "Spray: (.+)")
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

local function updatePetFromManualSummon(txt)
  local match = txt:match(regexPetNameInManualSummon)
  if match then all.inf.pet = tostring(match) or idk
    grint("updated active pet from manual pet summon, new active pet: " .. tostring(match))
  end
end

local function updatePetFromAutopet(txt)
  local match = txt:match(regexPetNameInAutopet)
  if match then all.inf.pet = tostring(match) or idk
    grint("updated active pet from autopet rule, new active pet: " .. tostring(match))
  end
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

---@param ticks number | nil
---@return boolean
function all.waiter(ticks)

  if ticks then
    if not all.dump.waiter or all.dump.waiter <= 0 then
      all.dump.waiter = ticks
      return true
    end
    return false
  end

  all.dump.waiter = all.dump.waiter - 1

  if all.dump.waiter <= 0 then
    all.dump.waiter = 0
    return true
  end
  return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

registerClientTickPost(function()

  updateCooldown()

  -- inf shit
  getTabInfo(player)
  all.inf.pos = player.getPos()
  all.inf.velocity = getVelocity()

  if all.dump.playerInputStopAllValue == true then
    _playerInputStopAll(player)
  end

  if all.dump.setPet and all.dump.setPet == true then
    _setPet(player)
  end

end)

--------------------------------------------------------------------------------

registerMessageEvent(function(text, overlay)

  if overlay then return end
  if not text then return end

  local txt = removeMinecraftColors(text)

  updatePetFromManualSummon(txt)
  updatePetFromAutopet(txt)

  -- if text then print("text: " .. tostring(text)) end
  -- if overlay then print("overlay: " .. tostring(overlay)) end

end)

--------------------------------------------------------------------------------

return all
