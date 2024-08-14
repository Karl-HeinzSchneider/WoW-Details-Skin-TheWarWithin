local TWW = LibStub('AceAddon-3.0'):NewAddon('Details_TWW', 'AceConsole-3.0')
local LocDetails = _G.LibStub("AceLocale-3.0"):GetLocale("Details")
local LSM = LibStub('LibSharedMedia-3.0')

local db

local debugMode = true
local skinName = '|cff8080ffThe War Within|r'

function TWW:OnInitialize()
    -- Called when the addon is loaded
    TWW:Debug('TWW:OnInitialize()')
end

function TWW:OnEnable()
    -- Called when the addon is enabled
    TWW:Debug('TWW:OnEnable()')

    if not Details then
        --
        TWW:Debug('no Details')
        return
    end

    self:Init()
end

function TWW:OnDisable()
    -- Called when the addon is disabled
end

function TWW:Debug(str, ...)
    if not debugMode then return end
    self:Print(str, ...)
end

function TWW:Init()
    local current = Details:GetCurrentProfileName()
    TWW:Debug('current', current)

    TWW:RegisterTextures()

    C_Timer.After(3, function()
        --
        -- print('TIMER!')     
    end)
end

function TWW:RegisterTextures()
    local test = LSM:List('statusbar')
    -- DevTools_Dump(test)
    TWW:Debug('List Statusbar', #LSM:List('statusbar'))

    LSM:Register('statusbar', 'TheWarWithin', [[Interface\AddOns\Details_TWW\Textures\header.tga]])

    TWW:Debug('List Statusbar', #LSM:List('statusbar'))
end

