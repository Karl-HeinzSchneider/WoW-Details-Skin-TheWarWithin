---@type string, Details_TWW
local _, app = ...

-- AceDB-3.0 defaults. Missing keys in the SavedVariables fall back to these values,
-- and values equal to the default are not written to disk.

-- User settings, switchable per character via AceDBOptions.
---@class Details_TWW.DB.Profile
local profile = {
    logLevel = "INFO",
    minimap = {
        hide = false,
        -- Degrees around the minimap (0 = east, counter-clockwise), written by LibDBIcon on drag.
        -- LibDBIcon puts every button at 225 when it has none, so buttons nobody has dragged yet
        -- all stack on one spot; start somewhere else instead.
        minimapPos = 200,
    },
    -- Skin for Blizzard's built-in damage meter (src/blizzard/damagemeter.lua).
    blizzardDamageMeter = {
        enabled = true,
        -- The bar fill texture: "default" (grey by luminance) or "bright" (grey by the brightest channel).
        barFill = "default",
    },
}

-- Data tied to one character.
---@class Details_TWW.DB.Char
local char = {}

-- Account-wide data shared by every character.
---@class Details_TWW.DB.Global
local global = {
    dbVersion = 1,
}

---@class Details_TWW.DBDefaults : AceDB.Schema
app.dbDefaults = {
    profile = profile,
    char = char,
    global = global,
}
