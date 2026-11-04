---@type string, Details_TWW
local appName, app = ...

local log = app.logger
local addon = app.addon

-- The addon's options as one AceConfig table, shown in the game's Settings panel (AddOns tab) and
-- in a standalone window (`/details_tww`), so an option is added here once.
---@class Details_TWW.Options : AceModule
local module = {}
app.options = addon:NewModule("Options", module) --[[@as Details_TWW.Options]]

-- The log levels for the select, quietest first, shown as "Info" for "INFO".
local levelNames, levelOrder = {}, {}
for name in pairs(log.level) do
    levelNames[name] = name:sub(1, 1) .. name:sub(2):lower()
    levelOrder[#levelOrder + 1] = name
end
table.sort(levelOrder, function(a, b)
    return log.level[a] < log.level[b]
end)

local options = {
    type = "group",
    name = appName,
    args = {
        blizzardDamageMeter = {
            type = "toggle",
            order = 1,
            width = "full",
            name = "Skin the Blizzard damage meter",
            desc = "Applies the 'The War Within' skin to the game's built-in damage meter, whichever style is picked in Edit Mode.",
            get = function()
                return app.db.profile.blizzardDamageMeter.enabled
            end,
            set = function(_, value)
                app.db.profile.blizzardDamageMeter.enabled = value
                app.blizzardDamageMeter:OnProfileRefresh()
            end,
        },
        blizzardDamageMeterBarFill = {
            type = "select",
            order = 2,
            name = "Bar texture",
            desc = "The fill of the damage meter bars. Bright shows the class color almost at full strength.",
            values = { default = "Default", bright = "Bright" },
            sorting = { "default", "bright" },
            disabled = function()
                return not app.db.profile.blizzardDamageMeter.enabled
            end,
            get = function()
                return app.db.profile.blizzardDamageMeter.barFill
            end,
            set = function(_, value)
                app.db.profile.blizzardDamageMeter.barFill = value
                app.blizzardDamageMeter:OnProfileRefresh()
            end,
        },
        detailsApply = {
            type = "execute",
            order = 5,
            width = "double",
            name = "Apply to all Details! windows",
            desc = "Switches every open Details! window to the 'The War Within' skin. The skin is also in the skin list of Details!' own options, to pick it per window.",
            confirm = true,
            confirmText = "Switch every open Details! window to the 'The War Within' skin? This replaces the windows' appearance settings.",
            hidden = function()
                return not app.detailsSkin:IsAvailable()
            end,
            func = function()
                local count = app.detailsSkin:ApplyToAllWindows()
                log:chat("Applied the Details! skin to %d window(s).", count)
            end,
        },
        minimap = {
            type = "toggle",
            order = 10,
            width = "full",
            name = "Show minimap button",
            desc = "The minimap button opens these options.",
            get = function()
                return not app.db.profile.minimap.hide
            end,
            set = function(_, value)
                app.db.profile.minimap.hide = not value
                app.minimapButton:OnProfileRefresh()
            end,
        },
        logLevel = {
            type = "select",
            order = 20,
            name = "Log level",
            desc = "How much " .. appName .. " writes to the chat window. Same as /details_tww loglevel <level>.",
            values = levelNames,
            sorting = levelOrder,
            get = function()
                return app.db.profile.logLevel
            end,
            set = function(_, value)
                if log:setLevel(value) then
                    app.db.profile.logLevel = log:getLevelName()
                end
            end,
        },
    },
}

-- Runs after addon:OnInitialize, so app.db is available.
function module:OnInitialize()
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(app.db)
    options.args.profiles.order = 100

    LibStub("AceConfig-3.0"):RegisterOptionsTable(appName, options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(appName)
end

-- Toggles the options in a standalone window.
function module:Open()
    local dialog = LibStub("AceConfigDialog-3.0")
    if dialog.OpenFrames[appName] then
        dialog:Close(appName)
    else
        dialog:Open(appName)
    end
end

-- Redraws the options wherever they are shown, after a setting changed outside of them.
function module:Refresh()
    LibStub("AceConfigRegistry-3.0"):NotifyChange(appName)
end

-- A profile switch, copy or reset changes every value.
function module:OnProfileRefresh()
    self:Refresh()
end
