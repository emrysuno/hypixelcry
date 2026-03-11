local gcu = require("goonCommsUtils")
local gsm = require("goonStateMachine")
local gst = require("goonStates")
local gut = require("goonUtils")
local gui = require("goonUi")
local gog = require("goonLog")
local vgl = require("CryVigilance/index")
local rot = require("rotations_v3")
local blu = require("blockUtils")

-- initialization --------------------------------------------------------------

gog.info("use /goon to open the menu")

-- init state machine
local stm = gsm.StateMachine:new()
stm.log = gog
stm.rot = rot
stm.blockUtils = blu

-- init states
local sts = {} -- sts stands for states but i like 3 letter variables so fuck you
sts.standby = stm:addState(gsm.State:new("standby"))
sts.idle = stm:addState(gsm.State:new("idle"))
sts.claiming = stm:addState(gsm.State:new("claiming"))

-- templates
sts.aotv = stm:addState(gst.StateAotv.new("aotv"))
sts.mining = stm:addState(gst.StateMining.new("mining"))

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

-- states ----------------------------------------------------------------------

-- state standby ---------------------------------------------------------------

function sts.standby:onEnter()
  self:critical("standby")
end

-- state idle ------------------------------------------------------------------

function sts.idle:onEnter()

  if not gcu.locations.warpForge:isPlayerAtGoal() then
    player.sendCommand("/warp forge")
    self:debug("/warp forge")
    self.wait = 20
  end

end

function sts.idle:onUpdate()

  if not gcu.locations.warpForge:isPlayerAtGoal() then
    self.machine:switch(sts.standby)
    return
  end

  -- -- for test purposes
  -- if not tmp.test then
  --   sts.aotv:init(
  --     gcu.locations.cliffside_veins.path,
  --     function()
  --       sts.mining:init(sts.standby, { "wool", "prismarine", "cyan_terracotta" }, 3)
  --     end)
  --   return
  -- end

  -- claim if any comms are done
  if gcu.commsClaimable() then
    sts.aotv:init(gcu.locations.forge_emissary.path, sts.claiming)
    return
  end

  -- otherwise go mining
  if tmp.activeComm then
    sts.aotv:init(
      gcu.locations[tmp.activeComm.comm_location_index].path,
      function()
        sts.mining:init(
          sts.idle,
          gcu.commsClaimable,
          tmp.activeComm.comm_mineable_type or gcu.mineables.mithril
        )
      end
    )
    return
  end

  self:info("no comms to do, standing by")
  self.machine:switch(sts.standby)

end

-- state claiming -----------------------------------------------------------------

function sts.claiming:onEnter()
  tmp.claimingSlots = { 11, 12, 14, 15 }
end

function sts.claiming:onUpdate()

  if #tmp.claimingSlots == 0 then self.machine:switch(sts.idle) end

  -- open emissary inventory
  if not player.inventory.isAnyScreenOpened() then
    player.input.leftClick()
    self:debug("left clicking emissary")
    self.wait = math.random(15, 20)
    return
  end

  local slot = tmp.claimingSlots[1]
  local item = player.inventory.getStackFromContainer(slot)
  if not item or not item.lore then goto claimingIdk end
  if gut.isTextInLore("COMPLETED", item.lore, true) then
    player.inventory.leftClick(slot)
    self:debug("clicking slot " .. slot)
  end

  ::claimingIdk::
  table.remove(tmp.claimingSlots, 1)
  self.wait = math.random(15, 20)

end

function sts.claiming:onExit()
  player.inventory.closeScreen()
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
    if tmp.activeComm and i == tmp.activeComm.comm_index then
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
    table.insert(content, { text = "target: " .. (
      sts.mining.target and tostring(sts.mining.target.box) or "idk") }
    )
    table.insert(content, { text = "location: " .. tostring(tmp.location) })

  end

  gui.content = content

end)

registerKeyEvent(function(key, action)
  if key == 343 and action == "Release" then
    tmp.tgl.main = not tmp.tgl.main
  end
end)

registerWorldRenderer(function (context)

  if not sts.mining.target then return end

  local t = sts.mining.target
  local line = {
    x = t.x, y = t.y, z = t.z,
    red = 255, green = 0, blue = 0, alpha = 255,
    line_width = 2
  }
  -- context.renderLineFromCursor(line)
  context.renderOutline(line)

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
