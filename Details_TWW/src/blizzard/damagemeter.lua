---@type string, Details_TWW
local _, app = ...

local log = app.logger
local addon = app.addon

-- Skins Blizzard's built-in damage meter (Blizzard_DamageMeter, the same code on every client).
--
-- There is no API for this: the meter's styles are a fixed Edit Mode enum (Enum.DamageMeterStyle),
-- so no new style can be registered. Instead we hook, never replace, the functions that apply a style
-- or an icon and swap in our art right after Blizzard's code ran. Only art is touched; anchors, bar
-- colors and the values (secret values in 12.x) stay Blizzard's. Turning the skin off puts Blizzard's
-- art back.
--
-- Hooked functions (Blizzard_DamageMeter):
--   DamageMeterEntryMixin.UpdateStyle      every bar, on setup and on every style/icon change; also
--                                          the spell bars of the source window (same mixin)
--   DamageMeterEntryMixin.UpdateIcon       every bar, on every data refresh (Init)
--   DamageMeterEntryMixin.SetBarHeight     every bar, when the Edit Mode bar height changes (icon size)
--   DamageMeter:SetupSessionWindow         every session window, on creation and re-setup
-- XML mixins are copied into a frame when it is created, so a hook on the mixin table only reaches
-- frames created afterwards; frames that already exist are hooked one by one (see hookFrame).
--
-- Atlases can carry texture slice settings, and SetTexture keeps them, so every region we reuse gets
-- its slice margins reset. The window header is our own texture instead (Blizzard's is only faded out),
-- sliced so its ornaments keep their size on wide windows.

local BLIZZARD_ADDON = "Blizzard_DamageMeter"

local TEXTURE_PATH = "Interface\\AddOns\\Details_TWW\\assets\\skin\\"
local TEXTURES = {
    header = TEXTURE_PATH .. "header", -- 256x32; gold lines in rows 2 and 27
    classIcons = TEXTURE_PATH .. "ClassIconsTWW", -- 512x512; 64px cells, see CLASS_ICON_CELLS
    -- Blizzard's cast bar sheet (1024x512). The file is on every client, but not every client has its
    -- atlases, so the regions are cut out by texture coordinates.
    castingBar = "Interface\\CastingBar\\UICastingBar2x",
}

-- 512x32; Blizzard's cast bar fill (ui-castingbar-full-channel) in grey, so the class color tints it.
-- Picked by profile.blizzardDamageMeter.barFill.
local BAR_FILLS = {
    default = TEXTURE_PATH .. "bar_fill", -- grey by luminance
    bright = TEXTURE_PATH .. "bar_fill_bright", -- grey by the brightest channel
}

-- header.blp: the left curl is in columns 1-13 and the right ornament around 160-220; only the plain
-- part between them stretches.
local HEADER_SLICE = { left = 20, top = 0, right = 100, bottom = 0 }

-- Regions of UICastingBar2x (the retail atlases' coordinates), drawn around the bar like Blizzard's
-- cast bar and mirror timer do: background 1px and border 2px outside the StatusBar.
local BAR_BACKGROUND_TEXCOORD = { 0.0009765625, 0.4130859375, 0.3671875, 0.41796875 } -- ui-castingbar-background
local BAR_BORDER_TEXCOORD = { 0.412109375, 0.828125, 0.001953125, 0.060546875 } -- ui-castingbar-frame
local BAR_BACKGROUND_OUTSET = 1 -- the border region (BackgroundEdge) is already 2px out in Blizzard's XML

-- Blizzard's crop of the icon (DamageMeterEntry.xml), restored with its icon.
local BLIZZARD_ICON_TEXCOORD = { 0.0625, 0.9, 0.0626, 0.9 }

-- ClassIconsTWW.blp: {column, row} of the 64px cell of each class (same layout as Details!).
local CLASS_ICON_CELLS = {
    WARRIOR = { 0, 0 },
    MAGE = { 1, 0 },
    ROGUE = { 2, 0 },
    DRUID = { 3, 0 },
    EVOKER = { 4, 0 },
    HUNTER = { 0, 1 },
    SHAMAN = { 1, 1 },
    PRIEST = { 2, 1 },
    WARLOCK = { 3, 1 },
    PALADIN = { 0, 2 },
    DEATHKNIGHT = { 1, 2 },
    MONK = { 2, 2 },
    DEMONHUNTER = { 3, 2 },
}
local CLASS_ICON_CELL = 64 / 512
-- The round icons leave a 2px transparent margin in their cell; cropped so the icon fills its frame.
local CLASS_ICON_INSET = 2 / 512

-- Bar name and value: Friz Quadrata with a shadow, white (the legacy Details! skin), instead of
-- Blizzard's outlined Arial Narrow (NumberFontNormal). A Blizzard font object rather than SetFont with
-- a file, so the per-alphabet fallbacks (Korean, Chinese) are kept; the Edit Mode text size still
-- applies on top (SetTextScale). Looked up on use: font objects are globals from Blizzard's XML.
local BAR_FONT_OBJECT = "GameFontHighlight" -- SystemFont_Shadow_Med1: FRIZQT__ 12, shadow 1/-1

-- Blizzard's icon frame size (DamageMeterEntry.xml). With the skin on, the icon is a square as tall
-- as the bar row instead (the row height is the Edit Mode bar height).
local BLIZZARD_ICON_SIZE = 24

---@class Details_TWW.BlizzardDamageMeter : AceModule
---@field hooked boolean true once the Blizzard functions are hooked
local module = {}
app.blizzardDamageMeter = addon:NewModule("BlizzardDamageMeter", module) --[[@as Details_TWW.BlizzardDamageMeter]]

-- Everything we keep per Blizzard frame lives in these weak tables, never as fields on Blizzard's
-- frames (that would taint them).
---@type table<table, string>
local originalAtlas = setmetatable({}, { __mode = "k" }) -- region -> Blizzard's atlas
---@type table<StatusBar, string>
local originalFill = setmetatable({}, { __mode = "k" }) -- StatusBar -> Blizzard's fill atlas
---@type table<Frame, Texture>
local headers = setmetatable({}, { __mode = "k" }) -- session window -> our header texture
---@type table<Frame, boolean>
local skinnedIcons = setmetatable({}, { __mode = "k" }) -- entry -> shows our class icon
---@type table<FontString, Font>
local originalFont = setmetatable({}, { __mode = "k" }) -- font string -> Blizzard's font object

local function isEnabled()
    return app.db.profile.blizzardDamageMeter.enabled
end

local function barFillTexture()
    return BAR_FILLS[app.db.profile.blizzardDamageMeter.barFill] or BAR_FILLS.default
end

local function isSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function resetSlices(region)
    if region.SetTextureSliceMargins then
        region:SetTextureSliceMargins(0, 0, 0, 0)
    end
end

-- Remembers the region's current atlas, if it has one (after our SetTexture it has none).
local function rememberAtlas(region)
    local atlas = region:GetAtlas()
    if atlas and atlas ~= "" then
        originalAtlas[region] = atlas
    end
end

---@param region Texture
local function restoreTexture(region)
    local atlas = originalAtlas[region]
    if atlas then
        region:SetAtlas(atlas)
    end
end

-- The bar fill goes through the StatusBar API so the bar keeps handling its own fill coordinates
-- (which is also why the art is cropped into its own file instead of using SetTexCoord). The
-- texture region may be replaced by that call, so the class/role color is carried over.
---@param statusBar StatusBar
---@param asset string a file path or an atlas name
local function setBarFill(statusBar, asset)
    local fill = statusBar:GetStatusBarTexture()
    local r, g, b, a = 1, 1, 1, 1
    if fill then
        r, g, b, a = fill:GetVertexColor()
    end
    statusBar:SetStatusBarTexture(asset)
    statusBar:GetStatusBarTexture():SetVertexColor(r, g, b, a)
end

---@param region Texture
---@param texCoord number[]
local function setCastingBarRegion(region, texCoord)
    rememberAtlas(region)
    region:SetTexture(TEXTURES.castingBar)
    resetSlices(region)
    region:SetTexCoord(unpack(texCoord))
end

-- Bar fill, background and border of a session window bar or a source (spell) window bar.
--
-- Every Edit Mode style gets the same cast bar look; the style only decides the StatusBar's size and
-- position (Blizzard anchors it, we draw around it). Blizzard's own two regions are reused, since
-- their layers already fit: Background (BACKGROUND, anchored per style, so re-anchored here) and
-- BackgroundEdge (OVERLAY, already 2px outside the bar; hidden by the Bordered style, so shown here).
-- Both run after Blizzard's UpdateStyle, which resets them.
local function skinEntry(entry)
    local statusBar = entry.StatusBar
    if not statusBar then
        return
    end
    local background = statusBar.Background
    local border = statusBar.BackgroundEdge

    if isEnabled() then
        local fill = statusBar:GetStatusBarTexture()
        local atlas = fill and fill:GetAtlas()
        if atlas and atlas ~= "" then
            originalFill[statusBar] = atlas
        end
        setBarFill(statusBar, barFillTexture())
        resetSlices(statusBar:GetStatusBarTexture())

        if background then
            setCastingBarRegion(background, BAR_BACKGROUND_TEXCOORD)
            background:ClearAllPoints()
            background:SetPoint("TOPLEFT", -BAR_BACKGROUND_OUTSET, BAR_BACKGROUND_OUTSET)
            background:SetPoint("BOTTOMRIGHT", BAR_BACKGROUND_OUTSET, -BAR_BACKGROUND_OUTSET)
        end
        if border then
            setCastingBarRegion(border, BAR_BORDER_TEXCOORD)
            border:Show()
        end
    else
        local atlas = originalFill[statusBar]
        if atlas then
            setBarFill(statusBar, atlas)
            originalFill[statusBar] = nil
        end
        -- Back to the style's own layout, from Blizzard's getters (they only read the style).
        local style = entry.GetStyle and entry:GetStyle()
        if background then
            restoreTexture(background)
            if style and entry.GetBackgroundInsetsForStyle then
                local left, top, right, bottom = entry:GetBackgroundInsetsForStyle(style)
                background:ClearAllPoints()
                background:SetPoint("TOPLEFT", left, top)
                background:SetPoint("BOTTOMRIGHT", right, bottom)
            end
        end
        if border then
            restoreTexture(border)
            if style and entry.GetBackgroundEdgeVisibilityForStyle then
                border:SetShown(entry:GetBackgroundEdgeVisibilityForStyle(style))
            end
        end
    end
end

-- Player bars only: a spell bar (source window) shows the spell's icon, a creature has no class.
local function isSourceEntry(entry)
    return DamageMeterSourceEntryMixin and entry.Init == DamageMeterSourceEntryMixin.Init
end

-- Puts Blizzard's icon back, from the icon cache UpdateIcon keeps on the entry.
local function restoreIcon(entry, icon)
    if entry.iconAtlasElement then
        icon:SetAtlas(entry.iconAtlasElement)
    else
        icon:SetTexture(entry.iconTexture)
        icon:SetTexCoord(unpack(BLIZZARD_ICON_TEXCOORD))
    end
end

-- Replaces Blizzard's class/spec icon of a player bar with our class icon.
local function skinIcon(entry)
    local iconFrame = entry.Icon
    local icon = iconFrame and iconFrame.Icon
    if not icon then
        return
    end

    local classFilename = isSourceEntry(entry) and entry.classFilename
    local cell = classFilename and not isSecret(classFilename) and CLASS_ICON_CELLS[classFilename]

    if isEnabled() and cell then
        icon:SetTexture(TEXTURES.classIcons)
        resetSlices(icon)
        local left, top = cell[1] * CLASS_ICON_CELL, cell[2] * CLASS_ICON_CELL
        icon:SetTexCoord(
            left + CLASS_ICON_INSET,
            left + CLASS_ICON_CELL - CLASS_ICON_INSET,
            top + CLASS_ICON_INSET,
            top + CLASS_ICON_CELL - CLASS_ICON_INSET
        )
        skinnedIcons[entry] = true
    elseif skinnedIcons[entry] then
        restoreIcon(entry, icon)
        skinnedIcons[entry] = nil
    end
end

local function skinSessionWindow(window)
    local blizzardHeader = window.Header
    if not blizzardHeader then
        return
    end

    local header = headers[window]
    if isEnabled() then
        if not header then
            header = window:CreateTexture(nil, "BACKGROUND", nil, 1)
            header:SetAllPoints(blizzardHeader)
            header:SetTexture(TEXTURES.header)
            if header.SetTextureSliceMargins then
                header:SetTextureSliceMargins(
                    HEADER_SLICE.left,
                    HEADER_SLICE.top,
                    HEADER_SLICE.right,
                    HEADER_SLICE.bottom
                )
                if Enum.UITextureSliceMode then
                    header:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
                end
            end
            headers[window] = header
        end
        header:Show()
        -- Faded out, not hidden: other parts of the window are anchored to it.
        blizzardHeader:SetAlpha(0)
    else
        if header then
            header:Hide()
        end
        blizzardHeader:SetAlpha(1)
    end
end

-- Sizes the icon frame of any bar (player or spell): as tall as the row with the skin on, Blizzard's
-- 24px otherwise. The StatusBar is anchored to the icon frame's right edge, so the bar follows.
local function sizeIcon(entry)
    local iconFrame = entry.Icon
    if not iconFrame then
        return
    end
    local size = BLIZZARD_ICON_SIZE
    if isEnabled() then
        local height = entry:GetHeight()
        if height and height > 0 then
            size = height
        end
    end
    iconFrame:SetSize(size, size)
end

---@param fontString FontString?
local function skinFont(fontString)
    if not fontString then
        return
    end
    local font = _G[BAR_FONT_OBJECT]
    if isEnabled() and font then
        local current = fontString:GetFontObject()
        if current ~= font then
            originalFont[fontString] = current
            fontString:SetFontObject(font)
        end
    elseif originalFont[fontString] then
        fontString:SetFontObject(originalFont[fontString])
        originalFont[fontString] = nil
    end
end

-- Name and value of any bar. Blizzard sets their font only in XML, so once per frame is enough; the
-- UpdateStyle hook reaches every frame the scroll box creates.
local function skinText(entry)
    local statusBar = entry.StatusBar
    if statusBar then
        skinFont(statusBar.Name)
        skinFont(statusBar.Value)
    end
end

local function onUpdateStyle(entry)
    skinEntry(entry)
    sizeIcon(entry)
    skinText(entry)
end

local function skinEntryFully(entry)
    onUpdateStyle(entry)
    skinIcon(entry)
end

-- Every bar a session window currently shows, its local-player bar and its source window's bars.
local function forEachEntryOfWindow(window, func)
    if window.ForEachEntryFrame then
        window:ForEachEntryFrame(func)
    end
    local container = window.MinimizeContainer
    if container then
        if container.LocalPlayerEntry then
            func(container.LocalPlayerEntry)
        end
        local sourceWindow = container.SourceWindow
        if sourceWindow and sourceWindow.ForEachEntryFrame then
            sourceWindow:ForEachEntryFrame(func)
        end
    end
end

local function forEachSessionWindow(func)
    local meter = DamageMeter
    if not meter or not meter.GetWindowDataList or not meter:GetWindowDataList() then
        return -- the window list is built on VARIABLES_LOADED
    end
    meter:ForEachSessionWindow(func)
end

-- A frame created before the mixin was hooked still holds Blizzard's unhooked copy of the function.
local function hookFrame(frame, method, mixin, handler)
    if frame[method] and frame[method] ~= mixin[method] then
        hooksecurefunc(frame, method, handler)
    end
end

function module:InstallHooks()
    if self.hooked then
        return
    end
    local entryMixin = DamageMeterEntryMixin
    if not entryMixin or not entryMixin.UpdateStyle or not entryMixin.UpdateIcon or not DamageMeter then
        log:warn("Blizzard damage meter found, but not in the expected shape; skin not applied")
        return
    end
    self.hooked = true

    hooksecurefunc(entryMixin, "UpdateStyle", onUpdateStyle)
    hooksecurefunc(entryMixin, "UpdateIcon", skinIcon)
    if entryMixin.SetBarHeight then
        hooksecurefunc(entryMixin, "SetBarHeight", sizeIcon)
    end
    hooksecurefunc(DamageMeter, "SetupSessionWindow", function(_, _, windowData)
        if windowData and windowData.sessionWindow then
            skinSessionWindow(windowData.sessionWindow)
        end
    end)

    forEachSessionWindow(function(window)
        forEachEntryOfWindow(window, function(entry)
            hookFrame(entry, "UpdateStyle", entryMixin, onUpdateStyle)
            hookFrame(entry, "UpdateIcon", entryMixin, skinIcon)
            hookFrame(entry, "SetBarHeight", entryMixin, sizeIcon)
        end)
    end)

    log:debug("Blizzard damage meter hooked")
end

-- Applies or removes the skin on everything that exists right now.
function module:Apply()
    if not self.hooked then
        return
    end
    forEachSessionWindow(function(window)
        skinSessionWindow(window)
        forEachEntryOfWindow(window, skinEntryFully)
    end)
end

-- Runs after addon:OnInitialize, so app.db is available.
function module:OnInitialize()
    -- Runs right away when Blizzard_DamageMeter is already loaded (the normal case), otherwise once
    -- it loads; on a client without it nothing happens.
    EventUtil.ContinueOnAddOnLoaded(BLIZZARD_ADDON, function()
        self:InstallHooks()
        self:Apply()
    end)
end

function module:OnProfileRefresh()
    self:Apply()
end
