local all = {}

all.config = {
  logTypes = {
    info = {
      text = "INFO",
      color = "§a",
      enabled = true
    },
    debug = {
      text = "DEBUG",
      color = "§d",
      enabled = true
    },
    error = {
      text = "ERROR",
      color = "§c",
      enabled = true
    },
    critical = {
      text = "CRITICAL",
      color = "§4",
      enabled = true
    },
  },
  colorMessage = "§7",
  colorPrefix = "§8",
  colorSuffix = "§8",
  logPrefix = "[",
  logSuffix = "]"
}

---@param logType table
---@return string
local function logBuilder(logType)
  local x = all.config
  local ret = x.colorPrefix .. x.logPrefix .. logType.color .. logType.text .. x.colorSuffix .. x.logSuffix .. " " .. x.colorMessage
  return ret
end

function all.info(text)
  if not all.config.logTypes.info.enabled then return end
  player.addMessage(logBuilder(all.config.logTypes.info) .. text)
end

function all.debug(text)
  if not all.config.logTypes.debug.enabled then return end
  player.addMessage(logBuilder(all.config.logTypes.debug) .. text)
end

function all.error(text)
  if not all.config.logTypes.error.enabled then return end
  player.addMessage(logBuilder(all.config.logTypes.error) .. text)
end

function all.critical(text)
  if not all.config.logTypes.critical.enabled then return end
  player.addMessage(logBuilder(all.config.logTypes.critical) .. text)
end

return all
