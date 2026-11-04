---@type string, Details_TWW
local appName, app = ...

local log = app.logger
local addon = app.addon

-- Same texture as the TOC's `## IconTexture`.
local ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Prototype: Ace attaches it to the real module object via __index, so methods are defined
-- here but state (self.ldb, ...) lives on the object NewModule returns.
---@class Details_TWW.MinimapButton : AceModule
---@field ldb LibDataBroker.QuickLauncher
local module = {}
app.minimapButton = addon:NewModule("MinimapButton", module) --[[@as Details_TWW.MinimapButton]]

-- Runs after addon:OnInitialize, so app.db is available.
function module:OnInitialize()
    ---@type LibDataBroker.QuickLauncher
    local launcher = {
        type = "launcher",
        text = appName,
        icon = ICON,
        OnClick = function(_, button)
            self:OnClick(button)
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(appName)
            tooltip:AddLine("Left-click: options", 1, 1, 1)
        end,
    }
    self.ldb = LibStub("LibDataBroker-1.1"):NewDataObject(appName, launcher) --[[@as LibDataBroker.QuickLauncher]]

    LibStub("LibDBIcon-1.0"):Register(appName, self.ldb, app.db.profile.minimap)
    log:debug("Minimap button registered")
end

-- Re-read hide/position from the (possibly new) profile.
-- The addon's first OnProfileRefresh runs before module:OnInitialize, hence the guard.
function module:OnProfileRefresh()
    local icon = LibStub("LibDBIcon-1.0")
    if icon:IsRegistered(appName) then
        icon:Refresh(appName, app.db.profile.minimap)
    end
end

---@param button string "LeftButton", "RightButton", ...
function module:OnClick(button)
    if button == "LeftButton" then
        app.options:Open()
    else
        log:debug("Minimap button clicked (%s)", button)
    end
end
