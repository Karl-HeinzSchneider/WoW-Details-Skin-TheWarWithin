---@type string, Details_TWW
local _, app = ...

local log = app.logger
local addon = app.addon

-- The "The War Within" skin for Details! (only when Details! is installed).
--
-- Details! has a skin API: Details:InstallSkin(name, skin) adds the skin to the skin list of its
-- options, and instance:ChangeSkin(name) applies it to a window by copying skin.instance_cprops over
-- the window's settings. Installing therefore changes no window; the user picks the skin in Details!,
-- or presses "Apply to all Details! windows" in our options (ApplyToAllWindows).
--
-- Every texture a window uses (bar fill, bar background, bar overlay, title bar) is looked up through
-- LibSharedMedia by name, so ours are registered there. A Details! bar always covers its whole row,
-- so the row textures (512x64, a 32px row at 2x) carry the cast bar in their bottom 15px and are
-- transparent above it, where the texts go:
--   fill (row_info.texture)                  the grey cast bar fill, 2px inside the bar box
--   background (row_info.texture_background) Blizzard's cast bar background, 1px inside
--   border (row_info.overlay_texture)        Blizzard's cast bar frame; the overlay sits above the
--                                            fill and is not cut by the bar's value
-- The skin's own callback is no longer called by Details!, so what settings cannot do is hooked:
--   Details.RefreshTitleBar                   3-slice the title bar so its ornaments don't stretch
--   Details.ChangeSkin                        hide the window texture's own header band behind it
--   Details.InstanceRefreshRows,              anchor the row background to the bar instead of the
--   Details.gump.CreateNewLine                whole row (which includes the icon)
--   Details.SetClassIcon                      our class icon where Details! can't map Blizzard's
--                                             spec icon (WoW Forever)
--
-- Details! starts its windows one frame after PLAYER_LOGIN, after every addon loaded, so registering
-- and installing in OnInitialize is early enough. no_cache: Details! would otherwise keep its own copy
-- of the table in its saved variables, which goes stale and points at our textures after we're gone.

-- The legacy skin's name: windows and profiles saved with it find this skin under the same name.
local SKIN_NAME = "|cff8080ffThe War Within|r"

local TEXTURE_PATH = "Interface\\AddOns\\Details_TWW\\assets\\skin\\"

-- LibSharedMedia "statusbar" media.
local MEDIA = {
    header = "TWW Header",
    barFill = "TWW Bar",
    barFillBright = "TWW Bar Bright",
    barBackground = "TWW Bar Background",
    barBorder = "TWW Bar Border",
}
local MEDIA_FILES = {
    [MEDIA.header] = TEXTURE_PATH .. "header",
    [MEDIA.barFill] = TEXTURE_PATH .. "details_bar_fill",
    [MEDIA.barFillBright] = TEXTURE_PATH .. "details_bar_fill_bright",
    [MEDIA.barBackground] = TEXTURE_PATH .. "details_bar_background",
    [MEDIA.barBorder] = TEXTURE_PATH .. "details_bar_border",
    -- The legacy skin's media names, still stored in the windows that used it.
    TheWarWithinHeader = TEXTURE_PATH .. "header",
    TheWarWithinBar = TEXTURE_PATH .. "details_bar_fill",
    TheWarWithinBackground = TEXTURE_PATH .. "details_bar_background",
}

-- header.blp: the left curl is in columns 1-13 and the right ornament around 160-220; only the plain
-- part between them stretches (same as the Blizzard damage meter header).
local HEADER_SLICE = { left = 20, top = 0, right = 100, bottom = 0 }

local ROW_HEIGHT = 32 -- the height the row textures are drawn for
local TITLE_BAR_HEIGHT = 32 -- header.blp is 256x32
local WHITE = { 1, 1, 1, 1 }

---@class Details_TWW.DetailsSkin : AceModule
---@field installed boolean true once the skin is in Details!' skin list
local module = {}
app.detailsSkin = addon:NewModule("DetailsSkin", module) --[[@as Details_TWW.DetailsSkin]]

-- Text above the bar: the bar takes the bottom 15 of 32px, so the texts' centre moves up by ~7px.
local TEXT_Y_OFFSET = 7

local function rowText(color)
    return {
        color = { byClass = false, fixed = color },
        font = { outline = "" },
        shadow = { color = { 0, 0, 0, 1 }, offset = { 1, -1 } },
    }
end

-- The skin table for Details:InstallSkin. Window frame art and anchors follow Details!' own
-- "Minimalistic v2" (no side bars, no status bar); instance_cprops are the window settings it applies.
local function buildSkin()
    return {
        file = [[Interface\AddOns\Details\images\skins\classic_skin.blp]],
        author = "Karl-Heinz Schneider",
        version = "2.0",
        site = "https://www.curseforge.com/wow/addons/details-skin-the-war-within",
        desc = "The War Within: cast bar style bars, round class and spec icons and the TWW title bar.",
        no_cache = true,

        micro_frames = { color = { 1, 1, 1, 0.7 }, font = "Friz Quadrata TT", size = 9, textymod = 0 },

        can_change_alpha_head = true,
        icon_anchor_main = { -1, -5 },
        icon_anchor_plugins = { -7, -13 },
        icon_plugins_size = { 19, 18 },

        icon_point_anchor = { -37, 0 },
        left_corner_anchor = { -107, 0 },
        right_corner_anchor = { 96, 0 },
        icon_point_anchor_bottom = { -37, 12 },
        left_corner_anchor_bottom = { -107, 0 },
        right_corner_anchor_bottom = { 96, 0 },

        icon_on_top = true,
        icon_ignore_alpha = true,
        icon_titletext_position = { 5, 4 },

        instance_cprops = {
            -- window
            color = { 0.3058, 0.3058, 0.3058, 0.8838 },
            bg_r = 0.0941,
            bg_g = 0.0941,
            bg_b = 0.0941,
            bg_alpha = 0, -- the background behind the rows: none by default, set per window in Details!
            backdrop_texture = "Details Ground",
            show_sidebars = false,
            show_statusbar = false,
            hide_icon = true,
            toolbar_side = 1,
            micro_displays_side = 2,
            plugins_grow_direction = 1,
            strata = "LOW",

            -- title bar: our header, the attribute name in gold Friz Quadrata like the Blizzard meter
            titlebar_shown = true,
            titlebar_height = TITLE_BAR_HEIGHT,
            titlebar_texture = MEDIA.header,
            titlebar_texture_color = WHITE,
            attribute_text = {
                enabled = true,
                shadow = true,
                side = 1,
                text_face = "Friz Quadrata TT",
                text_size = 13,
                text_color = { NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1 },
                anchor = { -18, 10 },
                custom_text = "{name}",
                enable_custom_text = false,
            },
            menu_anchor = { 16, 10, side = 2 },
            menu_anchor_down = { 16, -2 },
            menu_icons_alpha = 0.92,
            menu_icons_size = 0.9,
            desaturated_menu = false,
            color_buttons = WHITE,

            -- rows
            row_info = {
                height = ROW_HEIGHT,
                space = { left = 0, right = 0, between = 2 },

                texture = MEDIA.barFill,
                texture_class_colors = true,
                texture_background = MEDIA.barBackground,
                texture_background_class_color = false,
                fixed_texture_background_color = WHITE,
                overlay_texture = MEDIA.barBorder,
                overlay_color = WHITE,
                alpha = 1,
                -- ChangeSkin copies cprops two levels deep, so a table here replaces the window's
                -- whole table: give every key Details! reads (row_info.texts is the exception,
                -- Details! fills its missing keys from its defaults)
                backdrop = {
                    enabled = false,
                    size = 12,
                    color = { 1, 1, 1, 1 },
                    texture = "Details BarBorder 2",
                    use_class_colors = false,
                },

                -- the icon is as tall as the row (Details! sizes it so), the bar starts after it
                icon_file = TEXTURE_PATH .. "ClassIconsTWW",
                use_spec_icons = true,
                spec_file = TEXTURE_PATH .. "specs",
                no_icon = false,
                start_after_icon = true,
                icon_offset = { 0, 0 },
                icon_size_offset = 0,

                font_face = "Friz Quadrata TT",
                font_size = 12,
                fixed_text_color = { 1, 1, 1 },
                text_yoffset = TEXT_Y_OFFSET,
                textL_show_number = true,
                textR_show_data = { true, true, true },
                textR_bracket = "(",
                textR_separator = ",",
                texts = {
                    [1] = rowText({ 1, 1, 1, 1 }),
                    [2] = rowText({ 1, 1, 1, 1 }),
                    [3] = rowText({ 1, 1, 1, 1 }),
                    [4] = rowText({ 1, 1, 1, 1 }),
                },
            },
        },
    }
end

local function registerMedia(media)
    for name, file in pairs(MEDIA_FILES) do
        media:Register("statusbar", name, file)
    end
end

-- 3-slices the title bar texture of windows using our header; other windows get their plain texture
-- back (the margins would otherwise stay on the texture after a skin change).
---@param instance table a Details! window
local function sliceTitleBar(instance)
    local titleBar = instance.baseframe and instance.baseframe.titleBar
    local texture = titleBar and titleBar.texture
    if not texture or not texture.SetTextureSliceMargins then
        return
    end
    local ours = instance.titlebar_texture == MEDIA.header or instance.titlebar_texture == "TheWarWithinHeader"
    if ours then
        texture:SetTextureSliceMargins(HEADER_SLICE.left, HEADER_SLICE.top, HEADER_SLICE.right, HEADER_SLICE.bottom)
        if texture.SetTextureSliceMode and Enum.UITextureSliceMode then
            texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        end
    else
        texture:SetTextureSliceMargins(0, 0, 0, 0)
    end
end

-- The window frame texture (skin.file) also draws a header band of its own (the corner pieces
-- "ball"/"ball_r", "emenda" and "top_bg" of cabecalho, regions of the base frame) behind our title
-- bar, a dark strip around the drag frame DetailsUpFrameInstance<id>. They are hidden while a window
-- uses our skin; hidden regions keep their place as anchors for the menu buttons and the drag frame.
-- Details! never shows them again itself (it hides "ball" on creation), so only the regions we hid
-- are shown again when the window switches to another skin.
local HEADER_BAND_REGIONS = { "ball", "emenda", "top_bg", "ball_r" }

---@type table<Texture, boolean>
local hiddenBandRegions = setmetatable({}, { __mode = "k" })

---@param instance table a Details! window
local function updateHeaderBand(instance)
    local header = instance and instance.baseframe and instance.baseframe.cabecalho
    if not header then
        return
    end
    local ours = instance.skin == SKIN_NAME
    for _, key in ipairs(HEADER_BAND_REGIONS) do
        local region = header[key]
        if region then
            if ours then
                if region:IsShown() then
                    region:Hide()
                    hiddenBandRegions[region] = true
                end
            elseif hiddenBandRegions[region] then
                region:Show()
                hiddenBandRegions[region] = nil
            end
        end
    end
end

-- Windows Details! created and skinned before our hooks existed.
local function updateExistingWindows()
    local details = _G.Details
    if not details or not details.ListInstances then
        return
    end
    for _, instance in details:ListInstances() do
        updateHeaderBand(instance)
    end
end

---@param instance table a Details! window
local function usesOurBackground(instance)
    local background = instance.row_info and instance.row_info.texture_background
    return background == MEDIA.barBackground or background == "TheWarWithinBackground"
end

-- Rows whose background we anchored to the bar, so it can go back to the row when the window
-- switches to another background.
---@type table<Frame, boolean>
local movedBackgrounds = setmetatable({}, { __mode = "k" })

-- Details! anchors a row's background to the whole row once, when the row is created, so it also
-- spans the icon. Our background is part of the bar (it carries the bar's background and is drawn
-- like the fill and border), so it is anchored to the StatusBar instead.
---@param instance table a Details! window
---@param row table? a Details! row (instance.barras[i])
local function anchorRowBackground(instance, row)
    local background = row and row.background
    if not background or not row.statusbar then
        return
    end
    if usesOurBackground(instance) then
        background:ClearAllPoints()
        background:SetAllPoints(row.statusbar)
        movedBackgrounds[row] = true
    elseif movedBackgrounds[row] then
        background:ClearAllPoints()
        background:SetAllPoints(row)
        movedBackgrounds[row] = nil
    end
end

-- Called as instance:InstanceRefreshRows() and as Details:InstanceRefreshRows(instance).
local function onRefreshRows(self, instance)
    instance = instance or self
    if not instance or not instance.barras then
        return
    end
    for _, row in ipairs(instance.barras) do
        anchorRowBackground(instance, row)
    end
end

-- gump:CreateNewLine(instance, index) stores the new row in instance.barras[index].
local function onCreateNewLine(_, instance, index)
    if instance and instance.barras then
        anchorRowBackground(instance, instance.barras[index])
    end
end

-- With Blizzard's damage meter data (Retail and WoW Forever), Details! gets a spec icon file id per
-- player and maps it to a spec of its own table, drawn from row_info.spec_file. An id it can't map
-- (an unknown id, or a secret one: on WoW Forever specIconID is always secret) is drawn as Blizzard's
-- square icon instead; on our skin that becomes the class icon from row_info.icon_file
-- (classFilename is never secret).
-- Details! (Details:SetClassIcon) maps a few icons by hand where its table has a spec it has no cell for.
local SPEC_ICON_FALLBACK = { [461112] = 253, [608953] = 269, [135846] = 64, [136145] = 265 }

-- Whether Details! finds a cell of row_info.spec_file for a Blizzard spec icon, decided the way
-- Details:SetClassIcon decides it (the drawn texture is not read back: GetTexture may not return the
-- file id it was given).
---@param specIcon number
---@return boolean
local function detailsMapsSpecIcon(specIcon)
    local framework, specCoords = _G.DetailsFramework, _G.Details.class_specs_coords
    if not framework or not framework.GetSpecInfoFromSpecIcon or not specCoords then
        return true -- can't tell; leave Details!' icon alone
    end
    local specInfo = framework:GetSpecInfoFromSpecIcon(specIcon)
    local specId = specInfo and specInfo.specId
    if specId and not specCoords[specId] then
        specId = SPEC_ICON_FALLBACK[specIcon] or specId
    end
    return specId ~= nil and specCoords[specId] ~= nil
end

-- Called as actor:SetClassIcon(texture, instance, class) and Details.SetClassIcon(actor, ...).
local function onSetClassIcon(actor, texture, instance, class)
    if not instance or instance.skin ~= SKIN_NAME or not texture or type(actor) ~= "table" then
        return
    end
    local rowInfo = instance.row_info
    local specIcon = actor.thisSpecIcon
    if not rowInfo or not rowInfo.use_spec_icons or not specIcon then
        return
    end
    -- A secret icon (always on WoW Forever, where specIconID is a SecretValue; never on Retail) can't
    -- be looked up, by Details! or by us, so Details! drew it as it is: show the class instead.
    local secret = issecretvalue and issecretvalue(specIcon)
    if not secret and detailsMapsSpecIcon(specIcon) then
        return
    end
    local coords = _G.Details.class_coords
    class = class or actor.classe
    local cell = coords and (type(class) == "string" and coords[class] or coords.UNKNOW)
    if not cell then
        return
    end
    texture:SetTexture(rowInfo.icon_file)
    texture:SetTexCoord(unpack(cell))
end

function module:Install()
    if self.installed then
        return
    end
    local details = _G.Details
    if not details or not details.InstallSkin then
        return
    end
    local media = LibStub("LibSharedMedia-3.0", true)
    if not media then
        log:warn("LibSharedMedia-3.0 not found; Details! skin not installed")
        return
    end

    registerMedia(media)
    if not details:InstallSkin(SKIN_NAME, buildSkin()) then
        log:warn("Details! refused the skin")
        return
    end
    self.installed = true

    if details.RefreshTitleBar then
        hooksecurefunc(details, "RefreshTitleBar", sliceTitleBar)
    end
    if details.ChangeSkin then
        hooksecurefunc(details, "ChangeSkin", updateHeaderBand)
    end
    if details.InstanceRefreshRows then
        hooksecurefunc(details, "InstanceRefreshRows", onRefreshRows)
    end
    if details.gump and details.gump.CreateNewLine then
        hooksecurefunc(details.gump, "CreateNewLine", onCreateNewLine)
    end
    if details.SetClassIcon then
        hooksecurefunc(details, "SetClassIcon", onSetClassIcon)
    end
    updateExistingWindows()
    log:debug("Details! skin installed")
end

-- Switches every open Details! window to the skin. A window that already uses it is first marked as
-- using none, so Details! applies the skin's settings again instead of only refreshing it.
---@return number count windows changed
function module:ApplyToAllWindows()
    local details = _G.Details
    if not self.installed or not details or not details.ListInstances then
        return 0
    end
    local count = 0
    for _, instance in details:ListInstances() do
        if instance:IsEnabled() and instance.baseframe then
            if instance.skin == SKIN_NAME then
                instance.skin = ""
            end
            instance:ChangeSkin(SKIN_NAME)
            count = count + 1
        end
    end
    return count
end

function module:IsAvailable()
    return self.installed
end

-- Runs after addon:OnInitialize. Details! is an optional dependency, so it is loaded before us when
-- it is installed and enabled; without it nothing happens.
function module:OnInitialize()
    self:Install()
end
