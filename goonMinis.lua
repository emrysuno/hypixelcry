local vgl = require("CryVigilance/index")
local gut = require("goonUtils")

local tmp = {}
tmp.tgl = {}

-- inits -----------------------------------------------------------------------

-- init esp --------------------------------------------------------------------

local esp = {}

esp.cfg = {
  scan_interval = 4,
  -- recheck_radius = 10.0,
  -- search_radius = 0.65,
  box_expand_y = 2.0,
  recheck_dist_sq = 10.0 * 10.0,
  tracers = false,
  targets = {
    "star"
  },
  textures = {
    -- rat
    ["ewogICJ0aW1lc3RhbXAiIDogMTYxODQxOTcwMTc1MywKICAicHJvZmlsZUlkIiA6ICI3MzgyZGRmYmU0ODU0NTVjODI1ZjkwMGY4OGZkMzJmOCIsCiAgInByb2ZpbGVOYW1lIiA6ICJCdUlJZXQiLAogICJzaWduYXR1cmVSZXF1aXJlZCIgOiB0cnVlLAogICJ0ZXh0dXJlcyIgOiB7CiAgICAiU0tJTiIgOiB7CiAgICAgICJ1cmwiIDogImh0dHA6Ly90ZXh0dXJlcy5taW5lY3JhZnQubmV0L3RleHR1cmUvYThhYmI0NzFkYjBhYjc4NzAzMDExOTc5ZGM4YjQwNzk4YTk0MWYzYTRkZWMzZWM2MWNiZWVjMmFmOGNmZmU4IiwKICAgICAgIm1ldGFkYXRhIiA6IHsKICAgICAgICAibW9kZWwiIDogInNsaW0iCiAgICAgIH0KICAgIH0KICB9Cn0="] = true
  }
}
esp.render_style = {
  red = 255, green = 255, blue = 86, alpha = 140,
  line_width = 2,
  through_walls = true,
}
esp.entities = {}
esp.cache = {}
esp.tick = 0

--- @return boolean
function esp.isTarget(entity)

  if not entity then return false end

  -- check head texture (commented cuz not working)
  -- if entity.head and entity.head.head_texture then
  --   if esp.cfg.textures[entity.head.head_texture] then
  --     return true
  --   end
  -- end

  local box = entity.box
  if not box then return false end
  local scanArea = box.expand(0, esp.cfg.box_expand_y, 0)
  -- WARN: remove the 1st arg entity on 1.2.1.3
  local checkList = world.getEntitiesInBox(entity, scanArea) or {}

  for _, ent in ipairs(checkList) do
    if ent and ent.type == "entity.minecraft.armor_stand" then
      local dname = ent.display_name or ""
      -- check if target
      for _, targetName in ipairs(esp.cfg.targets) do
        if dname:lower():find(targetName:lower()) then
          return true
        end
      end
    end
  end

  return false
end

function esp.getDistanceSq(ePos, pPos)
  local e = ePos.position
  local p = pPos
  local dx, dy, dz = e.x - p.x, e.y - p.y, e.z - p.z
  return dx*dx + dy*dy + dz*dz
end

function esp.updateTargets()

  local p = player.getPos() if not p then return {} end
  local allEntities = world.getLivingEntities() or {}
  local found = {}
  local active = {}

  for _, entity in ipairs(allEntities) do
    local id = entity.id
    local etype = entity.type

    if entity ~= nil
    and entity.is_alive
    and etype ~= "entity.minecraft.armor_stand"
    and etype ~= "entity.minecraft.item"
    then
      active[id] = true
      local inCache = esp.cache[id]
      local distSq = esp.getDistanceSq(entity, p)
      local isNearby = inCache and (distSq <= esp.cfg.recheck_dist_sq)
      if inCache then
        -- reverify if nearby, otherwise trust cache
        if not isNearby or esp.isTarget(entity) then
          table.insert(found, entity)
        else
          esp.cache[id] = nil
        end
      elseif esp.isTarget(entity) then
        esp.cache[id] = true
        table.insert(found, entity)
      end
    end
  end

  -- clean up stale cache entries
  for id in pairs(esp.cache) do
    if not active[id] then esp.cache[id] = nil end
  end
  return found
end

-- registers -------------------------------------------------------------------

registerClientTickPre(function ()

  -- esp
  if tmp.tgl.esp then
    esp.tick = esp.tick + 1
    if esp.tick >= esp.cfg.scan_interval then
      esp.entities = esp.updateTargets()
      esp.tick = 0
    end
  end

end)

registerWorldRenderer(function (context)

  -- esp
  if tmp.tgl.esp then
    for _, entity in ipairs(esp.entities) do
      -- esp box
      if entity.box then
        esp.render_style.box = entity.box
        context.renderOutline(esp.render_style)
      end
      if esp.cfg.tracers then
        local line = {
          x = entity.x, y = entity.y, z = entity.z,
          red = esp.render_style.red,
          green = esp.render_style.green,
          blue = esp.render_style.blue,
          alpha = esp.render_style.alpha,
          line_width = esp.render_style.line_width
        }
        context.renderLineFromCursor(line)
      end
    end
  end

end)

-- vigilance -------------------------------------------------------------------

local cfg = vgl.new( "goon", "goon", nil, 345)
tmp.vgl = {
  category = "minis",
  subcategory = {
    esp = "esp",
    -- dev = "dev"
  }
}

-- subcategory esp ------------------------------------------------------------

cfg:addProperty({
  type        = vgl.TYPES.SWITCH,
  key         = "tglEsp",
  name        = "toggle",
  -- description = "turns on/off (keybind: windows-key)",
  category    = tmp.vgl.category,
  subcategory = tmp.vgl.subcategory.esp,
  default     = false,
})
cfg:onChanged("tglEsp", function(newValue)
  tmp.tgl.esp = newValue
end)

cfg:addProperty({
  type        = vgl.TYPES.SWITCH,
  key         = "tglEspTracer",
  name        = "tracers",
  -- description = "turns on/off (keybind: windows-key)",
  category    = tmp.vgl.category,
  subcategory = tmp.vgl.subcategory.esp,
  default     = false,
})
cfg:onChanged("tglEspTracer", function(newValue)
  esp.cfg.tracers = newValue
end)

cfg:addProperty({
  type        = vgl.TYPES.PARAGRAPH,
  key         = "espTargets",
  name        = "mobs to highlight",
  -- description = "names of mobs to highlight",
  category    = tmp.vgl.category,
  subcategory = tmp.vgl.subcategory.esp,
  default     = "idk\nuhh",
})
cfg:onChanged("espTargets", function(newValue)
  esp.cfg.targets = gut.paraToTable(newValue)
end)

-- vigilance end ---------------------------------------------------------------

cfg:initialize()
