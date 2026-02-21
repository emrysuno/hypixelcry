local notifications = {}

-- Простейшая функция кодирования
local function simpleEncode(str)
  if not str then return "" end
  str = tostring(str)

  -- Заменяем только пробелы и небезопасные символы
  local result = ""
  for i = 1, #str do
    local char = string.sub(str, i, i)
    local byte = string.byte(char)

    if char == " " then
      result = result .. "+"
    elseif (byte >= 32 and byte <= 126) and char ~= "&" and char ~= "=" and char ~= "?" then
      -- ASCII символы, которые безопасны в URL
      result = result .. char
    else
      -- Все остальные символы кодируем
      result = result .. string.format("%%%02X", byte)
    end
  end

  return result
end

-- for infinite duration use 0 (notification doesn't disappear)
notifications.defaultTimeout = 5000
-- low / normal / critical
notifications.defaultUrgency = "normal"

function notifications.snowNotifty(title, message, urgency, timeout)
  -- Используем encodeURIComponent через JavaScript если доступен
  -- или простую функцию кодирования
  local encodedTitle = simpleEncode(title)
  local encodedMessage = simpleEncode(message)

  local url =
  "http://localhost:8080/notify?title=" .. encodedTitle ..
  "&message=" .. encodedMessage

  -- urgency
  local encodedUrgency
  if urgency
  and (urgency == "low" or urgency == "normal" or urgency == "critical")
  then
    encodedUrgency = simpleEncode(urgency)
  else
    encodedUrgency = simpleEncode(notifications.defaultUrgency)
  end
  url = url .. "&urgency=" .. encodedUrgency

  -- timeout
  local encodedTimeout
  if timeout
  and type(timeout) == "number" then
    encodedTimeout = simpleEncode(timeout)
  else
    encodedTimeout = simpleEncode(notifications.defaultTimeout)
  end
  url = url .. "&timeout=" .. encodedTimeout

  http.get_async_callback(url, function(response, error)

  end)
end

return notifications
