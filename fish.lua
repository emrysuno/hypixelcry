local gui = require("goonUi.lua")
local gog = require("goonLog.lua")

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
  ATK = 3
}

-- tick ranges (random cooldown before doing stuff)
local CATCH = {2, 4} -- for catching after detection
local ATTACK = {1, 2} -- for attacking after catching
local RECAST = {2, 5} -- for recasting after catching

--- config end -----------------------------------------------------------------

local states = {
  fishing = "fishing",
  catching = "catching",
  attacking = "attacking",
  recasting = "recasting"
}
local state = states.fishing
local tick = 0
local wait = 0
local caught = 0

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
  if new_state == states.fishing then
    wait = math.random(5, 8)
  elseif new_state == states.catching then
    wait = math.random(CATCH[1], CATCH[2])
  elseif new_state == states.attacking then
    wait = math.random(ATTACK[1], ATTACK[2])
  elseif new_state == states.recasting then
    wait = math.random(RECAST[1], RECAST[2])
  end
end

--- registers ------------------------------------------------------------------

registerClientTickPre(function()

  -- consistent stuff but before early exists
  local curSlot = player.input.getSelectedSlot()

  -- early exits
  if player.inventory.isAnyScreenOpened()
  or (curSlot ~= SLOTS.ROD and curSlot ~= SLOTS.ATK)
  then
    tick = 0
    return
  end

  -- consistent stuff
  tickProceed()

  -- states

  -- scan for bite
  if state == states.fishing then

    if tick < wait then return end
    resetWait()
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

  elseif state == states.attacking then

    if tick < wait then return end
    resetWait()

    -- equip weapon
    if curSlot and curSlot ~= SLOTS.ATK then
      player.input.setSelectedSlot(SLOTS.ATK)
      gog.info("selected atk slot")
      wait = 1 -- delay after equipping weapon
      resetTick()
      return
    end

    -- attack
    player.input.silentUse(SLOTS.ATK)
    gog.info("attacked")
    stateSwitch(states.recasting)

  elseif state == states.recasting then

    if tick < wait then return end
    wait = 0

    -- re-equip rod
    if curSlot and curSlot ~= SLOTS.ROD then
      player.input.setSelectedSlot(SLOTS.ROD)
      gog.info("selected rod slot")
      wait = 2 -- delay after equipping rod
      resetTick()
      return
    end

    player.input.silentUse(SLOTS.ROD)
    gog.info("recasted")
    stateSwitch(states.fishing)

  end

end)


register2DRenderer(function(context)

  gui.content = {
    { text = "state: " .. state },
    { text = "tick: " .. tick },
    { text = "wait: " .. wait },
    { text = "caught: " .. caught }
  }

end)

return "marina feet"
