local gsm = require("goonStateMachine")
local gut = require("goonUtils")
local gui = require("goonUi")
local gog = require("goonLog")
local vgl = require("CryVigilance/index")
local gst = require("goonStates")
local rot = require("rotations_v3")
local gcu = require("goonCommsUtils")

-- initialization --------------------------------------------------------------

local stm = gsm.StateMachine.new()
local sts = {} -- sts stands for states but i like 3 letter variables so fuck you
-- create the state objects
sts.standby = stm:addState(gsm.State.new("standby"))
sts.idle = stm:addState(gsm.State.new("idle"))
sts.mining = stm:addState(gsm.State.new("mining"))
sts.claiming = stm:addState(gsm.State.new("claiming"))

-- templates
sts.aotv = stm:addState(gst.instantiateAotv())
sts.aotv.gog = gog
sts.aotv.rot = rot

-- rot
rot.setModifier(8)
-- rot.setRotationSpeed(20)

-- gut
gut.tgl.comms = true
gut.tgl.pos = true

-- gui
gui.config.gapInLinesFromTop = 2

-- gog
gog.config.logTypes.debug.enabled = true


-- helper vars / functions -----------------------------------------------------

local tmp = {}
tmp.tgl = {
  main = false,
  debug = false
}

local function gotoLocation(location, callback)
  sts.aotv.target = location.path
  sts.aotv.callback = callback
  stm:switch(sts.aotv)
end

-- states ----------------------------------------------------------------------

-- state standby ---------------------------------------------------------------

function sts.standby:onEnter()
  gog.critical("standby")
end

-- state idle ------------------------------------------------------------------

function sts.idle:onEnter()

  if not gcu.locations.warpForge:isPlayerAtGoal() then
    player.sendCommand("/warp forge")
    gog.debug(self.logPrefix .. "/warp forge")
    self.wait = 20
  end

end

function sts.idle:onUpdate()

  if not gcu.locations.warpForge:isPlayerAtGoal() then
    self.machine:switch(sts.standby)
    return
  end

  -- for test purposes
  -- gotoLocation(gcu.locations.cliffside_veins, sts.mining)

  -- claim if any comms are done
  if gcu.commsClaimable() then
    gotoLocation(gcu.locations.forge_emissary, sts.claiming)
    return
  end

  -- otherwise go mining
  if tmp.activeComm then
    gotoLocation(gcu.locations[tmp.activeComm[2]], sts.mining)
    return
  end

  gog.info("no comms to do, standing by")
  self.machine:switch(sts.standby)

end

-- state claiming -----------------------------------------------------------------

function sts.claiming:onEnter()
  self.slots = { 11, 12, 14, 15 }
end

function sts.claiming:onUpdate()

  if #self.slots == 0 then self.machine:switch(sts.idle) end

  -- open emissary inventory
  if not player.inventory.isAnyScreenOpened() then
    player.input.leftClick()
    gog.debug(self.logPrefix .. "left clicking emissary")
    self.wait = math.random(15, 20)
    return
  end

  local slot = self.slots[1]
  local item = player.inventory.getStackFromContainer(slot)
  if not item or not item.lore then goto claimingIdk end
  if gut.isTextInLore("COMPLETED", item.lore, true) then
    player.inventory.leftClick(slot)
    gog.debug(self.logPrefix .. "clicking slot " .. slot)
  end

  ::claimingIdk::
  table.remove(self.slots, 1)
  self.wait = math.random(15, 20)

end

function sts.claiming:onExit()
  player.inventory.closeScreen()
end

-- state mining ----------------------------------------------------------------

function sts.mining:onEnter()
  if tmp.location == nil then self.machine:switch(sts.standby) end
end

function sts.mining:onUpdate()

  if tmp.location == nil then self.machine:switch(sts.standby) end

  if gcu.commsClaimable() then
    self.machine:switch(sts.idle)
    return
  end

end

-- states end ------------------------------------------------------------------

stm:switch(sts.idle)

-- registers -------------------------------------------------------------------

registerClientTickPre(function()

  tmp.location = gcu.getLocation()
  tmp.activeComm = gcu.getActiveCommission()

  -- main toggle
  if not tmp.tgl.main then return end

  -- NOTE: maek an alert or something
  if gut.inf.comms == nil then return end

  rot.update()
  stm:update()

end)

register2DRenderer(function()

  local content = {}

  table.insert(content, {
    text = gut.getColoredStatusInStringOfAFunction("toggled", tmp.tgl.main)
  })

  table.insert(content, { text = "commissions:" })
  -- 4 commissions
  for i = 1, 4 do
    local s = gut.inf.comms and gut.inf.comms[i] or "ERROR"
    if tmp.activeComm and i == tmp.activeComm[1] then
      s = gut.clr.green .. s
    end
    table.insert(content, {
      text = "- " .. s
    })
  end

  if tmp.tgl.debug then

    table.insert(content, { text = "" })
    table.insert(content, { text = "[debug]" })
    table.insert(content, { text = "gtick: " .. stm.tick })
    table.insert(content, { text = "state: " .. ((stm.currentState and stm.currentState.name) or "nil") })
    table.insert(content, { text = "tick: " .. ((stm.currentState and stm.currentState.tick) or "-1") })
    table.insert(content, { text = "wait: " .. ((stm.currentState and stm.currentState.wait) or "-1") })
    table.insert(content, { text = "step: " .. ((stm.currentState and stm.currentState.step) or "-1") })
    table.insert(content, { text = "" })

    table.insert(content, { text = "location: " .. tostring(tmp.location) })

  end

  gui.content = content

end)

registerKeyEvent(function(key, action)
  if key == 343 and action == "Release" then
    tmp.tgl.main = not tmp.tgl.main
  end
end)

-- vigilance -------------------------------------------------------------------

local cfg = vgl.new( "goon", "goon", nil, 345)
tmp.vgl = {
  category = "goonAutoComms",
  subcategory = {
    main = "main",
    dev = "dev"
  }
}

-- subcategory main ------------------------------------------------------------

cfg:addProperty({
  type        = vgl.TYPES.SWITCH,
  key         = "tglMain",
  name        = "toggle",
  description = "turns on/off (keybind: windows-key)",
  category    = tmp.vgl.category,
  subcategory = tmp.vgl.subcategory.main,
  default     = false,
})
cfg:onChanged("tglMain", function(newValue)
  tmp.tgl.main = newValue
end)

-- subcategory dev -------------------------------------------------------------

cfg:addProperty({
  type        = vgl.TYPES.SWITCH,
  key         = "tglDebug",
  name        = "debug",
  description = "turns on/off",
  category    = tmp.vgl.category,
  subcategory = tmp.vgl.subcategory.dev,
  default     = false,
})
cfg:onChanged("tglDebug", function(newValue)
  tmp.tgl.debug = newValue
end)

cfg:initialize()
