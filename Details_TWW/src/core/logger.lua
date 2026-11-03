---@type string, Details_TWW
local appName, app = ...

---@class Details_TWW.Logger
---@operator call(...): nil
local logger = {}
app.logger = logger

-- Allow `log("msg")` as shorthand for `log:info("msg")`.
setmetatable(logger, {
    __call = function(self, ...)
        self:info(...)
    end,
})

---@alias Details_TWW.LogLevel integer

-- Higher number = more verbose. A message is shown when its level <= logger.threshold.
---@type table<string, Details_TWW.LogLevel>
logger.level = {
    NONE = -1,
    ERROR = 0,
    WARN = 1,
    INFO = 2,
    VERBOSE = 3,
    DEBUG = 4,
    SILLY = 5,
}

local levelNames = {}
for name, value in pairs(logger.level) do
    levelNames[value] = name
end

local levelColors = {
    [logger.level.ERROR] = "ff5555",
    [logger.level.WARN] = "ffaa00",
    [logger.level.INFO] = "55ff55",
    [logger.level.VERBOSE] = "55aaff",
    [logger.level.DEBUG] = "aaaaaa",
    [logger.level.SILLY] = "777777",
}

local PREFIX = "|cff33ccff" .. appName .. "|r"

-- Until OnInitialize applies profile.logLevel (default in db.lua).
logger.threshold = logger.level.INFO

-- Accepts a numeric level or a level name ("DEBUG", case-insensitive). Returns nil if invalid.
local function resolveLevel(level)
    if type(level) == "number" then
        return levelNames[level] and level or nil
    elseif type(level) == "string" then
        return logger.level[level:upper()]
    end
end

---@param level Details_TWW.LogLevel|string
---@return boolean
function logger:setLevel(level)
    local resolved = resolveLevel(level)
    if not resolved then
        self:error("Unknown log level: %s", tostring(level))
        return false
    end
    self.threshold = resolved
    return true
end

function logger:getLevelName(level)
    return levelNames[level or self.threshold] or "UNKNOWN"
end

---@param level Details_TWW.LogLevel
---@return boolean
function logger:isEnabled(level)
    return level <= self.threshold
end

-- Core output. `fmt` is passed through string.format when extra args are given,
-- otherwise it is printed as-is (so stray '%' in plain messages don't blow up).
---@param level Details_TWW.LogLevel
---@param fmt any
---@param ... any
function logger:print(level, fmt, ...)
    if level < 0 or not self:isEnabled(level) then
        return
    end

    local msg
    if select("#", ...) > 0 then
        local ok, result = pcall(string.format, tostring(fmt), ...)
        msg = ok and result or ("format error: " .. tostring(result))
    else
        msg = tostring(fmt)
    end

    local color = levelColors[level] or "ffffff"
    print(("%s |cff%s[%s]|r %s"):format(PREFIX, color, levelNames[level], msg))
end

-- Level shortcuts: logger:info("Looted %s x%d", link, count)
function logger:error(...)
    self:print(self.level.ERROR, ...)
end
function logger:warn(...)
    self:print(self.level.WARN, ...)
end
function logger:info(...)
    self:print(self.level.INFO, ...)
end
function logger:verbose(...)
    self:print(self.level.VERBOSE, ...)
end
function logger:debug(...)
    self:print(self.level.DEBUG, ...)
end
function logger:silly(...)
    self:print(self.level.SILLY, ...)
end

-- Plain user-facing chat output, never filtered by level and without a level tag.
function logger:chat(fmt, ...)
    local msg = select("#", ...) > 0 and tostring(fmt):format(...) or tostring(fmt)
    print(PREFIX .. ": " .. msg)
end

-- Dump a table one level deep; useful for inspecting event payloads while debugging.
function logger:dump(tbl, label)
    if not self:isEnabled(self.level.DEBUG) then
        return
    end
    if type(tbl) ~= "table" then
        self:debug("%s = %s", label or "value", tostring(tbl))
        return
    end
    self:debug("%s = {", label or "table")
    for k, v in pairs(tbl) do
        self:debug("    [%s] = %s", tostring(k), tostring(v))
    end
    self:debug("}")
end
