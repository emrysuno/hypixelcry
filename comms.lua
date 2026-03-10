local gsm = require("goonStateMachine")
local gut = require("goonUtils")
local gui = require("goonUi")
local gog = require("goonLog")
local vgl = require("CryVigilance/index")
local gst = require("goonStates")
local rot = require("rotations_v3")

-- initialization --------------------------------------------------------------

local stm = gsm.StateMachine.new()
local sts = {} -- sts stands for states but i like 3 letter variables so fuck you
-- create the state objects
sts.idle = stm:addState(gsm.State.new("idle"))
sts.followPath = stm:addState(gsm.State.new("followPath"))
sts.test = stm:addState(gsm.State.new("test"))
sts.aotv = stm:addState(gst.aotv)
sts.aotv.gog = gog
sts.aotv.rot = rot

-- rot
rot.setModifier(5)
-- rot.setRotationSpeed(20)

-- gut
gut.tgl.comms = true
gut.tgl.pos = true

-- gui
gui.config.gapInLinesFromTop = 2

-- custom
local tmp = {}
tmp.tgl = {
  main = false,
  debug = false
}
local paths = {
  test = {
    { x = 0.5, y = 166.5, z = -10.5 },
    { x = 0.5, y = 170.5, z = -3.5 }
  }
}

-- states ----------------------------------------------------------------------

-- state idle ------------------------------------------------------------------

function sts.idle:onEnter()

  player.sendCommand("/warp forge")
  gog.debug("/warp forge")

end

function sts.idle:onUpdate()

  if gut.isTargetInTableOfStrings("done", gut.inf.comms) then
    sts.followPath.currentPath = paths.test
    self.machine:switch(sts.followPath)
  end

end

-- state followPath ------------------------------------------------------------
-- currentPath - the current path to follow

function sts.followPath:onEnter()

  if not self.step then self.step = 1 end

end

function sts.followPath:onUpdate()

  local pos = gut.inf.pos

  -- exit if at currentPath goal
  if gut.isPosCloseTo(pos, self.currentPath[#self.currentPath], 1)
  then
    gog.debug(self.logPrefix .. "reached goal")
    self.machine:switch(sts.test)
    player.input.setPressedSneak(false)
    self.step = 1
    return
  end

  sts.aotv.target = self.currentPath[self.step]
  sts.aotv.callback = sts.followPath
  sts.aotv.postUnsneak = false
  self.machine:switch(sts.aotv)

end

function sts.followPath:onExit()
  self.step = self.step + 1
end

stm:switch(sts.idle)

-- registers -------------------------------------------------------------------

registerClientTickPre(function()

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
    table.insert(content, {
      text = "- " .. (gut.inf.comms and gut.inf.comms[i] or "ERROR")
    })
  end

  if tmp.tgl.debug then

    table.insert(content, { text = "" })
    table.insert(content, { text = "[debug]" })
    table.insert(content, { text = "gtick: " .. stm.tick })
    table.insert(content, { text = "state: " .. stm.currentState.name })
    table.insert(content, { text = "tick: " .. stm.currentState.tick })
    table.insert(content, { text = "wait: " .. stm.currentState.wait })
    local step = (stm.currentState.step and stm.currentState.step) or "-1"
    table.insert(content, { text = "step: " .. step })

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
